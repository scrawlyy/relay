import Libbox
import NetworkExtension

/// The PacketTunnelProvider owns the engine inside the extension process.
///
/// The app sends two command types over sendProviderMessage:
///   "stats"               -> JSON {upBytes, downBytes} from the engine
///   "probe|<timeout>|<url>" -> through-tunnel functional probe result JSON
class PacketTunnelProvider: NEPacketTunnelProvider, LibboxTrafficListenerProtocol {

    private var tunFd: Int32 = -1
    private var engineStarted = false

    // MARK: - Lifecycle

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol,
              let profile = protocolConfig.providerConfiguration?["profile"] as? [String: Any] else {
            completionHandler(PacketTunnelError.missingConfiguration)
            return
        }

        tunFd = createTunFD()
        guard tunFd >= 0 else {
            completionHandler(PacketTunnelError.tunCreationFailed)
            return
        }

        do {
            try setupEngine()
            let configJSON = try buildConfigJSON(profile: profile)
            try LibboxStartWithConfig(configJSON, tunFd)
            engineStarted = true
        } catch {
            if tunFd >= 0 { close(tunFd); tunFd = -1 }
            completionHandler(error)
            return
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 4064

        let ipv4 = NEIPv4Settings(addresses: ["10.7.0.1"], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(addresses: ["fdfe:dcba:9876::1"], networkPrefixLengths: [128])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        setTunnelNetworkSettings(settings) { error in
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        if engineStarted {
            try? LibboxStop()
            engineStarted = false
        }
        if tunFd >= 0 {
            close(tunFd)
            tunFd = -1
        }
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }
        let response: Data?
        if message == "stats" {
            let (up, down) = LibboxGetTraffic()
            response = try? JSONSerialization.data(withJSONObject: ["upBytes": up, "downBytes": down])
        } else if message.hasPrefix("probe|") {
            let parts = message.dropFirst("probe|".count).split(separator: "|", maxSplits: 1)
            if let timeoutStr = parts.first, let timeout = Int(timeoutStr),
               let url = parts.count > 1 ? String(parts[1]) : nil {
                response = tunnelProbeResponse(url: url, timeoutMs: timeout)
            } else {
                response = nil
            }
        } else {
            response = nil
        }
        completionHandler?(response)
    }

    private func tunnelProbeResponse(url: String, timeoutMs: Int) -> Data? {
        do {
            let outcome = try LibboxTunnelProbe(url, Int32(timeoutMs))
            return try? JSONSerialization.data(withJSONObject: [
                "ok": outcome.ok(),
                "connectRttMs": outcome.connectRTT(),
                "totalRttMs": outcome.totalRTT(),
                "httpStatus": outcome.httpStatus(),
                "error": outcome.error(),
            ])
        } catch {
            return try? JSONSerialization.data(withJSONObject: [
                "ok": false,
                "connectRttMs": 0,
                "totalRttMs": 0,
                "httpStatus": 0,
                "error": error.localizedDescription,
            ])
        }
    }

    // MARK: - Engine setup

    private func setupEngine() throws {
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.dev.relay"
        ) else {
            throw PacketTunnelError.appGroupUnavailable
        }
        let base = container.appendingPathComponent("engine", isDirectory: true)
        let working = base.appendingPathComponent("working", isDirectory: true)
        let temp = base.appendingPathComponent("temp", isDirectory: true)
        for directory in [base, working, temp] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try LibboxSetup(base.path, working.path, temp.path)
        LibboxSetTrafficListener(self)
    }

    private func buildConfigJSON(profile: [String: Any]) throws -> String {
        let config = LibboxProxyConfig()
        config.setType(profile["protocol"] as? String ?? "socks5")
        config.setServer(profile["host"] as? String ?? "")
        config.setPort(Int32((profile["port"] as? NSNumber)?.intValue ?? 0))
        config.setUsername(profile["username"] as? String ?? "")
        config.setPassword(profile["password"] as? String ?? "")

        let port = try LibboxAvailablePort(10000)
        let secret = LibboxRandomSecret(16)
        return LibboxBuildConfig(config, port, secret, 4064)
    }

    // MARK: - LibboxTrafficListenerProtocol

    func onTraffic(_ uplink: Int64, _ downlink: Int64) {
        // Accumulated totals are read on demand via handleAppMessage("stats");
        // no per-second work is needed here.
    }

    // MARK: - utun fd

    private func createTunFD() -> Int32 {
        let fd = socket(AF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL)
        guard fd >= 0 else { return -1 }
        var info = ctl_info()
        _ = strcpy(&info.ctl_name, "com.apple.net.utun_flow")
        let connected = withUnsafePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<ctl_info>.size))
            }
        }
        guard connected == 0 else {
            close(fd)
            return -1
        }
        return fd
    }
}

enum PacketTunnelError: LocalizedError {
    case missingConfiguration
    case tunCreationFailed
    case appGroupUnavailable

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Missing VPN configuration"
        case .tunCreationFailed:
            return "Failed to create utun interface"
        case .appGroupUnavailable:
            return "App group container unavailable"
        }
    }
}
