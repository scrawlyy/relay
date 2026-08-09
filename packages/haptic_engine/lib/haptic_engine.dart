import 'package:flutter/services.dart';

/// Semantic haptic events. Map exactly one UI action to one event so the
/// native layer can translate it to the platform's most expressive effect
/// (Taptic engine patterns on iOS, predefined vibration effects on Android).
enum HapticEvent {
  connectSuccess,
  connectFail,
  disconnect,
  toggle,
  selection,
  error,
}

/// Thin MethodChannel wrapper over the native haptics engines.
class HapticEngine {
  HapticEngine._();

  static const MethodChannel _channel = MethodChannel('dev.relay/haptics');

  static bool _enabled = true;

  /// Master switch (mirrored into the native layer).
  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on PlatformException {
      // Non-fatal: haptics degrade to nothing on unsupported platforms.
    }
  }

  /// Fire a semantic haptic event.
  static Future<void> trigger(HapticEvent event) async {
    if (!_enabled) return;
    try {
      await _channel.invokeMethod<void>('trigger', {'event': event.name});
    } on PlatformException {
      // Non-fatal.
    }
  }

  /// Convenience aliases for readability at call sites.
  static Future<void> success() => trigger(HapticEvent.connectSuccess);
  static Future<void> failure() => trigger(HapticEvent.connectFail);
  static Future<void> light() => trigger(HapticEvent.disconnect);
  static Future<void> tick() => trigger(HapticEvent.toggle);
}
