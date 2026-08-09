import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_providers.dart';
import 'settings_providers.dart';
import 'vpn_providers.dart';

class LatencyState {
  const LatencyState({this.ms, this.measuredAt, this.failed = false});

  /// End-to-end latency through the running tunnel, ms.
  final int? ms;
  final DateTime? measuredAt;
  final bool failed;

  bool get hasResult => ms != null || failed;

  static const idle = LatencyState();
}

/// Periodically measures end-to-end latency THROUGH the active tunnel using a
/// functional probe (sing-box URL-tests its own outbound). A failed probe is
/// surfaced as an error — we never report a bare TCP handshake as "latency".
final tunnelLatencyProvider =
    NotifierProvider<LatencyController, LatencyState>(LatencyController.new);

class LatencyController extends Notifier<LatencyState> {
  static const _interval = Duration(seconds: 15);

  Timer? _timer;
  bool _running = false;

  @override
  LatencyState build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(connectionProvider, (previous, next) {
      if (next.phase == ConnectionPhase.connected) {
        _start();
      } else {
        _stop();
      }
    });
    return LatencyState.idle;
  }

  void _start() {
    if (_running) return;
    _running = true;
    _measure();
    _timer = Timer.periodic(_interval, (_) => _measure());
  }

  void _stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    if (state.hasResult) {
      state = LatencyState.idle;
    }
  }

  Future<void> _measure() async {
    if (!_running) return;
    final vpn = ref.read(vpnPlatformProvider);
    final probeUrl = ref.read(settingsProvider).probeUrl;
    final outcome = await vpn.probeTunnel(probeUrl: probeUrl);
    if (!_running) return;
    if (outcome.ok) {
      state = LatencyState(ms: outcome.totalRttMs, measuredAt: DateTime.now());
    } else {
      state = LatencyState(failed: true, measuredAt: DateTime.now());
    }
  }

  Future<void> measureNow() async {
    if (!_running) return;
    await _measure();
  }
}
