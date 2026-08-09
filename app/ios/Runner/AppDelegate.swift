import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    // Retained: the haptic channel handler must outlive the channel wiring.
    private var hapticPlugin: HapticEnginePlugin?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(withRegistry: self)
        if let controller = window?.rootViewController as? FlutterViewController {
            hapticPlugin = HapticEnginePlugin(binaryMessenger: controller.binaryMessenger)
            VpnController.shared.registerChannels(with: controller)
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
