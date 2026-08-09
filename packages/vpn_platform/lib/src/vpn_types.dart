/// Shared types for the vpn_platform plugin.

/// Proxy protocol of a user-configured server.
enum ProxyProtocol { socks5, http }

/// A user-configured proxy profile. Passwords travel transiently to the native
/// layer in memory only (never persisted by the plugin).
class ProxyProfile {
  const ProxyProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  final String id;
  final String name;
  final ProxyProtocol protocol;
  final String host;
  final int port;
  final String? username;
  final String? password;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
      };

  factory ProxyProfile.fromMap(Map<dynamic, dynamic> map) => ProxyProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        protocol: ProxyProtocol.values.byName(map['protocol'] as String),
        host: map['host'] as String,
        port: (map['port'] as num).toInt(),
        username: map['username'] as String?,
        password: map['password'] as String?,
      );
}

/// Lifecycle state of the tunnel.
enum VpnState { disconnected, connecting, connected, disconnecting, error }

VpnState vpnStateFromName(String name) =>
    VpnState.values.firstWhere((s) => s.name == name,
        orElse: () => VpnState.disconnected);

/// Current tunnel status snapshot.
class VpnStatus {
  const VpnStatus({
    required this.state,
    this.profileId,
    this.profileName,
    this.latencyMs,
  });

  final VpnState state;
  final String? profileId;
  final String? profileName;

  /// Latest measured end-to-end latency through the tunnel, if measured.
  final int? latencyMs;

  factory VpnStatus.fromMap(Map<dynamic, dynamic> map) => VpnStatus(
        state: vpnStateFromName(map['state'] as String? ?? 'disconnected'),
        profileId: map['profileId'] as String?,
        profileName: map['profileName'] as String?,
        latencyMs: (map['latencyMs'] as num?)?.toInt(),
      );

  bool get isActive =>
      state == VpnState.connecting ||
      state == VpnState.connected ||
      state == VpnState.disconnecting;
}

/// Result of a diagnostic probe.
///
/// For [VpnPlatform.probeProxy] this is a *functional* check: the full proxy
/// handshake is performed and a real probe request is sent through the tunnel
/// and its HTTP response validated — so [ok] proves the proxy actually
/// forwards traffic, not merely that its TCP port responds.
class ProbeOutcome {
  const ProbeOutcome({
    required this.ok,
    this.connectRttMs = 0,
    this.totalRttMs = 0,
    this.httpStatus = 0,
    this.error,
  });

  final bool ok;

  /// RTT of the TCP dial + protocol handshake, in ms.
  final int connectRttMs;

  /// RTT of the full round trip including the through-tunnel probe request, ms.
  final int totalRttMs;

  /// HTTP status returned by the probe endpoint (204 for generate_204).
  final int httpStatus;

  final String? error;

  factory ProbeOutcome.fromMap(Map<dynamic, dynamic> map) => ProbeOutcome(
        ok: map['ok'] as bool? ?? false,
        connectRttMs: (map['connectRttMs'] as num?)?.toInt() ?? 0,
        totalRttMs: (map['totalRttMs'] as num?)?.toInt() ?? 0,
        httpStatus: (map['httpStatus'] as num?)?.toInt() ?? 0,
        error: map['error'] as String?,
      );
}

/// Result of a connect/disconnect action.
class VpnActionResult {
  const VpnActionResult({required this.success, this.errorCode, this.message});

  final bool success;
  final String? errorCode;
  final String? message;

  factory VpnActionResult.fromMap(Map<dynamic, dynamic> map) =>
      VpnActionResult(
        success: map['success'] as bool? ?? false,
        errorCode: map['errorCode'] as String?,
        message: map['message'] as String?,
      );
}

/// One 1 Hz traffic sample from the tunnel.
class StatsFrame {
  const StatsFrame({
    required this.upBytes,
    required this.downBytes,
    this.latencyMs,
    required this.ts,
  });

  final int upBytes;
  final int downBytes;
  final int? latencyMs;
  final DateTime ts;

  factory StatsFrame.fromMap(Map<dynamic, dynamic> map) => StatsFrame(
        upBytes: (map['upBytes'] as num?)?.toInt() ?? 0,
        downBytes: (map['downBytes'] as num?)?.toInt() ?? 0,
        latencyMs: (map['latencyMs'] as num?)?.toInt(),
        ts: DateTime.fromMillisecondsSinceEpoch(
            (map['ts'] as num?)?.toInt() ?? 0),
      );
}
