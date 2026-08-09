import 'package:haptic_engine/haptic_engine.dart';

/// Centralized haptic mapping so every action in the app fires exactly one
/// semantic event. Toggle off in settings to silence everything.
abstract final class AppHaptics {
  static bool _enabled = true;

  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await HapticEngine.setEnabled(enabled);
  }

  /// Button tap / switch flip.
  static Future<void> tap() =>
      _enabled ? HapticEngine.trigger(HapticEvent.toggle) : Future.value();

  /// Selecting an item.
  static Future<void> select() =>
      _enabled ? HapticEngine.trigger(HapticEvent.selection) : Future.value();

  /// Tunnel connected.
  static Future<void> connected() =>
      _enabled ? HapticEngine.trigger(HapticEvent.connectSuccess) : Future.value();

  /// Tunnel failed to connect.
  static Future<void> connectFailed() =>
      _enabled ? HapticEngine.trigger(HapticEvent.connectFail) : Future.value();

  /// Tunnel disconnected.
  static Future<void> disconnected() =>
      _enabled ? HapticEngine.trigger(HapticEvent.disconnect) : Future.value();

  /// Generic error / destructive action.
  static Future<void> error() =>
      _enabled ? HapticEngine.trigger(HapticEvent.error) : Future.value();
}
