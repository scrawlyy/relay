import Flutter
import Foundation
import NetworkExtension
import Libbox

/// App-side VPN controller.
///
/// - connect/disconnect/status: NETunnelProviderManager
/// - tcpPing / probeProxy: run in THIS process via the embedded Libbox
///   framework (no tunnel required) — probeProxy performs a functional
///   handshake + through-proxy probe request.
/// - probeTunnel / stats: routed to the PacketTunnel extension process via
///   sendProviderMessage (the engine and Clash API live there).
final class VpnController: NSObject {
    static let shared = VpnController()

    private let controlChannel = "dev.relay/vpn"
    private let statusChannel = "dev.relay/vpn/status"
    private let statsChannel = "dev.relay/vpn/stats"

    fileprivate var statusSink: FlutterEventSink?
    fileprivate var statsSink: FlutterEventSink?
    private var activeManager: NETunnelProviderManager?
    private var statsTimer: Timer?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Channel registration

    func registerChannels(with controller: FlutterViewController) {
        let messenger = controller.binaryMessenger

        let control = FlutterMethodChannel(name: controlChannel, binaryMessenger: messenger)
        control.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        FlutterEventChannel(name: statusChannel, binaryMessenger: messenger)
            .setStreamHandler(StatusStreamHandler(controller: self))
        FlutterEventChannel(name: statsChannel, binaryMessenger: messenger)
            .setStreamHandler(StatsStreamHandler(controller: self))
    }

    // MARK: - Method channel

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let profile = args["profile"] as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "expected {profile}", details: nil))
                return
            }
            connect(profile: profile, result: result)
        case "disconnect":
            disconnect(result: result)
        case "getStatus":
            result(statusMap())
        case "tcpPing":
            handleTcpPing(call, result: result)
        case "probeProxy":
            handleProbeProxy(call, result: result)
        case "probeTunnel":
            handleProbeTunnel(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Connect / disconnect

    private func connect(profile: [String: Any], result: @escaping FlutterResult) {
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.providerBundleIdentifier = "dev.relay.app.tunnel"
        protocolConfig.serverAddress = profile["host"] as? String ?? ""
        protocolConfig.disconnectOnSleep = false
        protocolConfig.providerConfiguration = ["profile": profile]

        let manager = NETunnelProviderManager()
        manager.localizedDescription = "Relay"
        manager.protocolConfiguration = protocolConfig
        manager.isEnabled = true

        manager.saveToPreferences { [weak self] error in
            guard let self else { return }
            if let error {
                result(success(false, "save_failed", error.localizedDescription))
                return
            }
            self.loadManagerAndStart(profile: profile, result: result)
        }
    }

    private func loadManagerAndStart(profile: [String: Any], result: @escaping FlutterResult) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self else { return }
            if let error {
                result(success(false, "load_failed", error.localizedDescription))
                return
            }
            guard let manager = managers?.first else {
                result(success(false, "no_manager", "VPN configuration missing"))
                return
            }
            self.activeManager = manager
            do {
                try manager.connection.startVPNTunnel(
                    options: ["profile": profile as NSObject]
                )
                result(success(true))
            } catch {
                result(success(false, "start_failed", error.localizedDescription))
            }
        }
    }

    private func disconnect(result: @escaping FlutterResult) {
        if let manager = activeManager {
            manager.connection.stopVPNTunnel()
        }
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            managers?.first?.connection.stopVPNTunnel()
        }
        result(success(true))
    }

    // MARK: - Diagnostics

    private func handleTcpPing(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let host = args["host"] as? String,
              let port = (args["port"] as? NSNumber)?.intValue else {
            result(FlutterError(code: "bad_args", message: "expected host/port", details: nil))
            return
        }
        let timeout = (args["timeoutMs"] as? NSNumber)?.intValue ?? 5000
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSError?
            guard let outcome = LibboxTCPPing(host, Int32(port), Int32(timeout), &error) else {
                result(self.probeMap(nil, error: error?.localizedDescription ?? "ping failed"))
                return
            }
            result(self.probeMap(outcome))
        }
    }

    private func handleProbeProxy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let profile = args["profile"] as? [String: Any] else {
            result(FlutterError(code: "bad_args", message: "expected {profile}", details: nil))
            return
        }
        let url = args["probeUrl"] as? String ?? ""
        let timeout = (args["timeoutMs"] as? NSNumber)?.intValue ?? 10000

        DispatchQueue.global(qos: .userInitiated).async {
            let config = LibboxProxyConfig()
            config.type = profile["protocol"] as? String ?? "socks5"
            config.server = profile["host"] as? String ?? ""
            config.port = Int32((profile["port"] as? NSNumber)?.intValue ?? 0)
            config.username = profile["username"] as? String ?? ""
            config.password = profile["password"] as? String ?? ""
            var error: NSError?
            guard let outcome = LibboxProxyProbe(config, url, Int32(timeout), &error) else {
                result(self.probeMap(nil, error: error?.localizedDescription ?? "probe failed"))
                return
            }
            result(self.probeMap(outcome))
        }
    }

    private func handleProbeTunnel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "bad_args", message: "expected args", details: nil))
            return
        }
        let url = args["probeUrl"] as? String ?? ""
        let timeout = (args["timeoutMs"] as? NSNumber)?.intValue ?? 10000
        sendProviderMessage("probe:\(url):\(timeout)") { response in
            guard let response else {
                result(self.probeMap(nil, error: "extension unreachable"))
                return
            }
            result(self.parseProbeResponse(response))
        }
    }

    // MARK: - Provider messaging (stats + tunnel probe)

    private func providerSession() -> NETunnelProviderSession? {
        if let session = activeManager?.connection as? NETunnelProviderSession {
            return session
        }
        var found: NETunnelProviderSession?
        let semaphore = DispatchSemaphore(value: 0)
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            found = managers?.first?.connection as? NETunnelProviderSession
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 3)
        return found
    }

    private func sendProviderMessage(
        _ command: String,
        completion: @escaping (Data?) -> Void
    ) {
        guard let session = providerSession() else {
            completion(nil)
            return
        }
        try? session.sendProviderMessage(Data(command.utf8)) { response in
            completion(response)
        }
    }

    // MARK: - Status / stats events

    @objc private func vpnStatusDidChange() {
        guard let sink = statusSink else { return }
        sink(statusMap())
        if statusMap()["state"] as? String == "connected" {
            startStatsPolling()
        } else {
            stopStatsPolling()
        }
    }

    fileprivate func statusMap() -> [String: Any?] {
        guard let manager = activeManager else {
            return ["state": "disconnected", "profileId": nil, "profileName": nil, "latencyMs": nil]
        }
        let state: String
        switch manager.connection.status {
        case .connecting: state = "connecting"
        case .connected: state = "connected"
        case .disconnecting: state = "disconnecting"
        case .disconnected: state = "disconnected"
        case .invalid: state = "disconnected"
        case .reasserting: state = "connecting"
        @unknown default: state = "disconnected"
        }
        let profile = (manager.protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["profile"] as? [String: Any]
        return [
            "state": state,
            "profileId": profile?["id"],
            "profileName": profile?["name"],
            "latencyMs": nil,
        ]
    }

    private func startStatsPolling() {
        stopStatsPolling()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollStats()
        }
        RunLoop.main.add(timer, forMode: .common)
        statsTimer = timer
    }

    private func stopStatsPolling() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func pollStats() {
        sendProviderMessage("stats") { [weak self] response in
            guard let self, let response,
                  let obj = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
                  let sink = self.statsSink else { return }
            var event: [String: Any] = obj
            event["ts"] = Int(Date().timeIntervalSince1970 * 1000)
            event["latencyMs"] = nil
            sink(event)
        }
    }

    // MARK: - Helpers

    private func success(_ ok: Bool, _ code: String? = nil, _ message: String? = nil) -> [String: Any?] {
        ["success": ok, "errorCode": code, "message": message]
    }

    private func probeMap(_ outcome: LibboxProbeResult?, error: String? = nil) -> [String: Any?] {
        if let outcome {
            return [
                "ok": outcome.ok,
                "connectRttMs": outcome.connectRTT,
                "totalRttMs": outcome.totalRTT,
                "httpStatus": outcome.httpStatus,
                "error": outcome.error,
            ]
        }
        return ["ok": false, "connectRttMs": 0, "totalRttMs": 0, "httpStatus": 0, "error": error]
    }

    private func parseProbeResponse(_ data: Data) -> [String: Any?] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return probeMap(nil, error: "invalid probe response")
        }
        return obj
    }
}

// MARK: - Stream handlers

private final class StatusStreamHandler: NSObject, FlutterStreamHandler {
    let controller: VpnController
    init(controller: VpnController) { self.controller = controller }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        controller.statusSink = events
        events(controller.statusMap())
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        controller.statusSink = nil
        return nil
    }
}

private final class StatsStreamHandler: NSObject, FlutterStreamHandler {
    let controller: VpnController
    init(controller: VpnController) { self.controller = controller }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        controller.statsSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        controller.statsSink = nil
        return nil
    }
}
