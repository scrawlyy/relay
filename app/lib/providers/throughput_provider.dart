import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpn_platform/vpn_platform.dart';

import 'connection_providers.dart';
import 'vpn_providers.dart';

class ThroughputPoint {
  const ThroughputPoint({
    required this.timestamp,
    required this.upRate,
    required this.downRate,
  });

  final DateTime timestamp;

  /// Bytes per second during the sample window.
  final int upRate;
  final int downRate;
}

class ThroughputState {
  const ThroughputState({
    this.points = const [],
    this.upTotal = 0,
    this.downTotal = 0,
  });

  final List<ThroughputPoint> points;
  final int upTotal;
  final int downTotal;

  ThroughputPoint? get latest =>
      points.isEmpty ? null : points.last;
}

/// Ring buffer of 1 Hz traffic samples for the dashboard chart + session totals.
final throughputProvider =
    NotifierProvider<ThroughputController, ThroughputState>(
        ThroughputController.new);

class ThroughputController extends Notifier<ThroughputState> {
  static const _capacity = 60;

  int? _lastUpTotal;
  int? _lastDownTotal;
  DateTime? _lastSampleAt;

  @override
  ThroughputState build() {
    ref.listen(vpnStatsProvider, (previous, next) {
      next.whenOrNull(data: _onFrame);
    });
    ref.listen(connectionProvider, (previous, next) {
      if (next.phase != ConnectionPhase.connected) {
        _reset();
      }
    });
    return const ThroughputState();
  }

  void _onFrame(StatsFrame frame) {
    final now = DateTime.now();
    var upRate = 0;
    var downRate = 0;

    final lastUp = _lastUpTotal;
    final lastDown = _lastDownTotal;
    final lastAt = _lastSampleAt;
    if (lastUp != null && lastDown != null && lastAt != null) {
      final dtMs = now.difference(lastAt).inMilliseconds;
      if (dtMs >= 200) {
        upRate = ((frame.upBytes - lastUp) * 1000 / dtMs)
            .round()
            .clamp(0, 1 << 40)
            .toInt();
        downRate = ((frame.downBytes - lastDown) * 1000 / dtMs)
            .round()
            .clamp(0, 1 << 40)
            .toInt();
      }
    }
    _lastUpTotal = frame.upBytes;
    _lastDownTotal = frame.downBytes;
    _lastSampleAt = now;

    final points = [...state.points, ThroughputPoint(
      timestamp: now,
      upRate: upRate,
      downRate: downRate,
    )];
    if (points.length > _capacity) {
      points.removeRange(0, points.length - _capacity);
    }

    state = ThroughputState(
      points: points,
      upTotal: frame.upBytes,
      downTotal: frame.downBytes,
    );
  }

  void _reset() {
    _lastUpTotal = null;
    _lastDownTotal = null;
    _lastSampleAt = null;
    state = const ThroughputState();
  }
}
