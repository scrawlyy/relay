import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpn_platform/vpn_platform.dart' as vpn;

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../platform/profile_adapter.dart';
import '../../providers/connection_providers.dart';
import '../../providers/profiles_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/vpn_providers.dart';
import '../shared/widgets.dart';

/// Diagnostic tools. The headline check is the FUNCTIONAL proxy probe: it
/// performs the full protocol handshake and sends a real probe request through
/// the proxy, so "working" means traffic actually flows — not merely that the
/// TCP port responds.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  vpn.ProbeOutcome? _functional;
  vpn.ProbeOutcome? _tcpPing;
  vpn.ProbeOutcome? _tunnel;
  bool _runningFunctional = false;
  bool _runningTcpPing = false;
  bool _runningTunnel = false;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeProfileProvider);
    final connection = ref.watch(connectionProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTokens.space),
          children: [
            const Text(
              'Diagnostics',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Checks run from this device against ${active?.displayHost ?? 'no profile'}',
              style: const TextStyle(fontSize: 13, color: AppTokens.textSecondary),
            ),
            const SizedBox(height: 8),

            _CheckCard(
              title: 'Proxy functional check',
              subtitle:
                  'Full SOCKS5/HTTP handshake, then a real probe request through '
                  'the proxy. Green = traffic actually flows.',
              icon: Icons.network_check,
              running: _runningFunctional,
              outcome: _functional,
              enabled: active != null,
              onRun: _runFunctional,
            ),
            const SizedBox(height: AppTokens.spaceSm),

            _CheckCard(
              title: 'Server reachability (TCP)',
              subtitle:
                  'Raw TCP handshake only — the port accepts connections, but '
                  'this does not prove the proxy works.',
              icon: Icons.dns_outlined,
              running: _runningTcpPing,
              outcome: _tcpPing,
              enabled: active != null,
              onRun: _runTcpPing,
            ),
            const SizedBox(height: AppTokens.spaceSm),

            _CheckCard(
              title: 'Through-tunnel check',
              subtitle: 'Probes from inside the running tunnel.',
              icon: Icons.hub_outlined,
              running: _runningTunnel,
              outcome: _tunnel,
              enabled: connection.phase == ConnectionPhase.connected,
              onRun: _runTunnel,
            ),
            const SizedBox(height: AppTokens.space),

            const SectionHeader(title: 'How checks work'),
            const _ExplainList(),
          ],
        ),
      ),
    );
  }

  Future<void> _runFunctional() async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) return;
    final full = await ref.read(profilesProvider.notifier).withPassword(profile);
    final probeUrl = ref.read(settingsProvider).probeUrl;
    setState(() {
      _runningFunctional = true;
      _functional = null;
    });
    final outcome = await ref
        .read(vpnPlatformProvider)
        .probeProxy(full.toVpnProfile(), probeUrl: probeUrl);
    if (!mounted) return;
    setState(() {
      _runningFunctional = false;
      _functional = outcome;
    });
    outcome.ok ? AppHaptics.connected() : AppHaptics.connectFailed();
  }

  Future<void> _runTcpPing() async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) return;
    setState(() {
      _runningTcpPing = true;
      _tcpPing = null;
    });
    final outcome = await ref
        .read(vpnPlatformProvider)
        .tcpPing(profile.host, profile.port);
    if (!mounted) return;
    setState(() {
      _runningTcpPing = false;
      _tcpPing = outcome;
    });
    outcome.ok ? AppHaptics.connected() : AppHaptics.connectFailed();
  }

  Future<void> _runTunnel() async {
    final probeUrl = ref.read(settingsProvider).probeUrl;
    setState(() {
      _runningTunnel = true;
      _tunnel = null;
    });
    final outcome = await ref
        .read(vpnPlatformProvider)
        .probeTunnel(probeUrl: probeUrl);
    if (!mounted) return;
    setState(() {
      _runningTunnel = false;
      _tunnel = outcome;
    });
    outcome.ok ? AppHaptics.connected() : AppHaptics.connectFailed();
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.running,
    required this.outcome,
    required this.enabled,
    required this.onRun,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool running;
  final vpn.ProbeOutcome? outcome;
  final bool enabled;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTokens.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _OutcomeView(outcome: outcome, running: running)),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: enabled && !running ? onRun : null,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Run'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.surfaceInteractive,
                  foregroundColor: AppTokens.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutcomeView extends StatelessWidget {
  const _OutcomeView({required this.outcome, required this.running});

  final vpn.ProbeOutcome? outcome;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (running) {
      return const Text(
        'Running…',
        style: TextStyle(fontSize: 12, color: AppTokens.textSecondary),
      );
    }
    final o = outcome;
    if (o == null) {
      return const Text(
        'Not run yet',
        style: TextStyle(fontSize: 12, color: AppTokens.textTertiary),
      );
    }
    final color = o.ok ? AppTokens.success : AppTokens.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          o.ok ? 'Working' : 'Failed',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (o.ok)
          Text(
            'HTTP ${o.httpStatus} · total ${formatLatency(o.totalRttMs)} · '
            'handshake ${formatLatency(o.connectRttMs)}',
            style: const TextStyle(fontSize: 11, color: AppTokens.textSecondary),
          )
        else
          Text(
            o.error ?? 'no response',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9)),
          ),
      ],
    );
  }
}

class _ExplainList extends StatelessWidget {
  const _ExplainList();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Probe endpoint', 'A 204 response from gstatic.com is the internet '
          'connectivity check Chrome uses. You can change it in Settings.'),
      ('Functional check', 'Dial → handshake → probe request through the '
          'tunnel → response validated. Success proves real egress.'),
      ('TCP ping', 'A raw TCP handshake. It can succeed while the proxy is '
          'broken (e.g. wrong credentials or no forwarding).'),
      ('Through-tunnel check', 'Runs inside the VPN using the engine’s own '
          'outbound test — live latency of the active tunnel.'),
    ];
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          for (final (title, body) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 5, color: AppTokens.textTertiary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
