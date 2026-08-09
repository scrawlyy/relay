import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpn_platform/vpn_platform.dart';

/// Native VPN facade (single instance).
final vpnPlatformProvider = Provider<VpnPlatform>((ref) => VpnPlatform.instance);

/// Live tunnel state transitions (connecting/connected/disconnected/error).
final vpnStatusProvider = StreamProvider<VpnStatus>((ref) {
  return ref.watch(vpnPlatformProvider).statusStream();
});

/// ~1 Hz traffic totals while connected.
final vpnStatsProvider = StreamProvider<StatsFrame>((ref) {
  return ref.watch(vpnPlatformProvider).statsStream();
});
