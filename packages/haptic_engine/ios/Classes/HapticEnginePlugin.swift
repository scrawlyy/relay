import Flutter
import UIKit

/// Semantic haptic events -> Taptic Engine generators.
///
/// - connectSuccess: notification(.success) + impact(.medium)
/// - connectFail:    notification(.error) + impact(.heavy)
/// - disconnect:     impact(.light)
/// - toggle:         selection()
/// - selection:      selection()
/// - error:          notification(.error)
///
/// The iOS app registers this class manually (see AppDelegate.swift) rather
/// than via a CocoaPods plugin, so the class also exposes a channel-based
/// initializer for use from the host target.
public class HapticEnginePlugin: NSObject, FlutterPlugin {
    private var impactLight = UIImpactFeedbackGenerator(style: .light)
    private var impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private var impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private var notification = UINotificationFeedbackGenerator()
    private var selection = UISelectionFeedbackGenerator()
    private var enabled = true

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dev.relay/haptics", binaryMessenger: registrar.messenger())
        let instance = HapticEnginePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    /// Convenience for manual registration from the host app (no plugin pod).
    public convenience init(binaryMessenger: FlutterBinaryMessenger) {
        self.init()
        let channel = FlutterMethodChannel(name: "dev.relay/haptics", binaryMessenger: binaryMessenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "trigger":
            guard let args = call.arguments as? [String: Any],
                  let name = args["event"] as? String else {
                result(FlutterError(code: "bad_args", message: "expected {event}", details: nil))
                return
            }
            trigger(name)
            result(nil)
        case "setEnabled":
            enabled = (call.arguments as? Bool) ?? true
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func trigger(_ name: String) {
        guard enabled else { return }
        switch name {
        case "connectSuccess":
            notification.prepare(); impactMedium.prepare()
            notification.notificationOccurred(.success)
            impactMedium.impactOccurred()
        case "connectFail":
            notification.prepare(); impactHeavy.prepare()
            notification.notificationOccurred(.error)
            impactHeavy.impactOccurred()
        case "disconnect":
            impactLight.prepare()
            impactLight.impactOccurred()
        case "toggle":
            selection.prepare()
            selection.selectionChanged()
        case "selection":
            selection.prepare()
            selection.selectionChanged()
        case "error":
            notification.prepare()
            notification.notificationOccurred(.error)
        default:
            break
        }
    }
}
