import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpn_platform/vpn_platform.dart';

import '../core/haptics/haptics.dart';
import '../domain/profile.dart';
import '../platform/profile_adapter.dart';
import 'profiles_providers.dart';
import 'vpn_providers.dart';

enum ConnectionPhase { disconnected, connecting, connected, disconnecting, error }

class ConnectionState {
  const ConnectionState({
    required this.phase,
    this.profile,
    this.errorMessage,
    this.connectedSince,
  });

  final ConnectionPhase phase;
  final Profile? profile;
  final String? errorMessage;
  final DateTime? connectedSince;

  static const idle = ConnectionState(phase: ConnectionPhase.disconnected);

  bool get isActive =>
      phase == ConnectionPhase.connecting ||
      phase == ConnectionPhase.connected ||
      phase == ConnectionPhase.disconnecting;

  ConnectionState copyWith({
    ConnectionPhase? phase,
    Profile? profile,
    String? errorMessage,
    DateTime? connectedSince,
  }) =>
      ConnectionState(
        phase: phase ?? this.phase,
        profile: profile ?? this.profile,
        errorMessage: errorMessage ?? this.errorMessage,
        connectedSince: connectedSince ?? this.connectedSince,
      );
}

/// Drives the tunnel lifecycle. Native status events (from the status stream)
/// are the source of truth; connect()/disconnect() issue commands and track a
/// short-lived "connecting" window locally.
final connectionProvider =
    NotifierProvider<ConnectionController, ConnectionState>(
        ConnectionController.new);

class ConnectionController extends Notifier<ConnectionState> {
  static const _connectTimeout = Duration(seconds: 20);

  bool _locallyConnecting = false;
  Timer? _connectTimer;
  ConnectionPhase _lastPhase = ConnectionPhase.disconnected;

  @override
  ConnectionState build() {
    ref.onDispose(() {
      _connectTimer?.cancel();
    });
    ref.listen(vpnStatusProvider, (previous, next) {
      next.whenOrNull(data: _onNativeStatus);
    });
    return ConnectionState.idle;
  }

  /// Connect the active profile. The actual transition to [ConnectionPhase.connected]
  /// arrives via the native status stream.
  Future<void> connect() async {
    final active = ref.read(activeProfileProvider);
    if (active == null) return;

    final profile = await ref.read(profilesProvider.notifier).withPassword(active);
    _locallyConnecting = true;
    state = ConnectionState(phase: ConnectionPhase.connecting, profile: profile);
    await AppHaptics.tap();

    final result = await ref
        .read(vpnPlatformProvider)
        .connect(profile.toVpnProfile());

    if (!result.success) {
      _locallyConnecting = false;
      _connectTimer?.cancel();
      state = ConnectionState(
        phase: ConnectionPhase.error,
        profile: profile,
        errorMessage: result.message ?? result.errorCode ?? 'Connection failed',
      );
      await AppHaptics.connectFailed();
      return;
    }

    _connectTimer?.cancel();
    _connectTimer = Timer(_connectTimeout, () {
      if (_locallyConnecting) {
        _locallyConnecting = false;
        state = ConnectionState(
          phase: ConnectionPhase.error,
          profile: profile,
          errorMessage: 'Connection timed out',
        );
        unawaited(AppHaptics.connectFailed());
      }
    });
  }

  Future<void> disconnect() async {
    _locallyConnecting = false;
    _connectTimer?.cancel();
    final profile = state.profile;
    state = ConnectionState(
      phase: ConnectionPhase.disconnecting,
      profile: profile,
    );
    await AppHaptics.tap();
    await ref.read(vpnPlatformProvider).disconnect();
  }

  void _onNativeStatus(VpnStatus status) {
    final phase = switch (status.state) {
      VpnState.connecting => ConnectionPhase.connecting,
      VpnState.connected => ConnectionPhase.connected,
      VpnState.disconnecting => ConnectionPhase.disconnecting,
      VpnState.error => ConnectionPhase.error,
      VpnState.disconnected => ConnectionPhase.disconnected,
    };

    // Ignore a "disconnected" echo while we are locally in a connect flow.
    if (_locallyConnecting &&
        phase == ConnectionPhase.disconnected &&
        _lastPhase != ConnectionPhase.connected) {
      return;
    }
    _locallyConnecting = false;
    _connectTimer?.cancel();

    final profile = _resolveProfile(status);
    final connectedSince =
        phase == ConnectionPhase.connected ? DateTime.now() : null;

    state = ConnectionState(
      phase: phase,
      profile: profile ?? state.profile,
      errorMessage: phase == ConnectionPhase.error ? 'Tunnel error' : null,
      connectedSince: connectedSince,
    );

    unawaited(_fireHapticForTransition(phase));
    _lastPhase = phase;
  }

  Profile? _resolveProfile(VpnStatus status) {
    final id = status.profileId;
    if (id == null) return null;
    final profiles = ref.read(profilesProvider);
    return profiles.where((p) => p.id == id).firstOrNull;
  }

  Future<void> _fireHapticForTransition(ConnectionPhase phase) async {
    if (_lastPhase == phase) return;
    switch (phase) {
      case ConnectionPhase.connected:
        await AppHaptics.connected();
      case ConnectionPhase.disconnected:
        if (_lastPhase == ConnectionPhase.connected) {
          await AppHaptics.disconnected();
        }
      case ConnectionPhase.error:
        await AppHaptics.error();
      default:
        break;
    }
  }
}
