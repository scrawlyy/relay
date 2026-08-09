import 'dart:async';

import 'package:flutter/services.dart';

import 'src/vpn_types.dart';

export 'src/vpn_types.dart';

/// Facade over the native VPN layer (Android VpnService, iOS Network
/// Extension). All diagnostics methods default to the functional probe:
/// traffic is actually sent through the proxy and the response validated —
/// never a bare TCP "is the port open" check.
class VpnPlatform {
  VpnPlatform._();

  static const MethodChannel _control = MethodChannel('dev.relay/vpn');
  static const EventChannel _statusEvents = EventChannel('dev.relay/vpn/status');
  static const EventChannel _statsEvents = EventChannel('dev.relay/vpn/stats');

  /// Default probe endpoint. A 204 from this host is the de-facto internet
  /// connectivity check used by Chrome/Google and validates real egress.
  static const String defaultProbeUrl = 'https://www.gstatic.com/generate_204';

  /// Start the tunnel for [profile].
  Future<VpnActionResult> connect(ProxyProfile profile) async {
    final result = await _control.invokeMapMethod<dynamic, dynamic>(
      'connect',
      {'profile': profile.toMap()},
    );
    return VpnActionResult.fromMap(result ?? const {});
  }

  /// Stop the tunnel.
  Future<VpnActionResult> disconnect() async {
    final result = await _control
        .invokeMapMethod<dynamic, dynamic>('disconnect');
    return VpnActionResult.fromMap(result ?? const {});
  }

  /// Current tunnel status.
  Future<VpnStatus> getStatus() async {
    final result = await _control
        .invokeMapMethod<dynamic, dynamic>('getStatus');
    return VpnStatus.fromMap(result ?? const {});
  }

  /// Reachability check: raw TCP handshake RTT to [host]:[port]. Reports only
  /// that the server accepts TCP — use [probeProxy] for a functional check.
  Future<ProbeOutcome> tcpPing(
    String host,
    int port, {
    int timeoutMs = 5000,
  }) async {
    final result = await _control.invokeMapMethod<dynamic, dynamic>(
      'tcpPing',
      {'host': host, 'port': port, 'timeoutMs': timeoutMs},
    );
    return ProbeOutcome.fromMap(result ?? const {});
  }

  /// FUNCTIONAL proxy check: connects to [profile]'s server, completes the
  /// full SOCKS5/HTTP-CONNECT handshake, then sends a real probe request
  /// through the tunnel and validates the HTTP response. [ok] means the proxy
  /// is actually working, not just responding.
  Future<ProbeOutcome> probeProxy(
    ProxyProfile profile, {
    String? probeUrl,
    int timeoutMs = 10000,
  }) async {
    final result = await _control.invokeMapMethod<dynamic, dynamic>(
      'probeProxy',
      {
        'profile': profile.toMap(),
        'probeUrl': probeUrl ?? defaultProbeUrl,
        'timeoutMs': timeoutMs,
      },
    );
    return ProbeOutcome.fromMap(result ?? const {});
  }

  /// End-to-end latency check THROUGH the currently running tunnel (the engine
  /// URL-tests its own outbound). Requires the tunnel to be connected.
  Future<ProbeOutcome> probeTunnel({
    String? probeUrl,
    int timeoutMs = 10000,
  }) async {
    final result = await _control.invokeMapMethod<dynamic, dynamic>(
      'probeTunnel',
      {'probeUrl': probeUrl ?? defaultProbeUrl, 'timeoutMs': timeoutMs},
    );
    return ProbeOutcome.fromMap(result ?? const {});
  }

  /// Live tunnel state transitions (connect/disconnect, VPN revoked by OS).
  Stream<VpnStatus> statusStream() =>
      _statusEvents.receiveBroadcastStream().map((event) {
        return VpnStatus.fromMap((event as Map<dynamic, dynamic>));
      });

  /// ~1 Hz accumulated traffic samples (upBytes/downBytes) while connected.
  Stream<StatsFrame> statsStream() =>
      _statsEvents.receiveBroadcastStream().map((event) {
        return StatsFrame.fromMap((event as Map<dynamic, dynamic>));
      });
}
