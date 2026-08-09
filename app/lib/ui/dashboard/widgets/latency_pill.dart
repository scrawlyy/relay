import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../providers/connection_providers.dart';
import '../../../providers/latency_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/vpn_providers.dart';
import '../../shared/widgets.dart';

/// Shows the last functional probe result measured THROUGH the running tunnel.
/// A failed probe is rendered as an error state — we never present a TCP
/// handshake as "latency".
class LatencyPill extends ConsumerWidget {
  const LatencyPill({super.key, required this.connection});

  final ConnectionState connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latency = ref.watch(tunnelLatencyProvider);
    final connected = connection.phase == ConnectionPhase.connected;

    if (!connected) {
      return const _Row(
        leading: Icon(Icons.network_ping, size: 16, color: AppTokens.textTertiary),
        text: 'Latency measured while connected',
        color: AppTokens.textTertiary,
      );
    }

    if (!latency.hasResult) {
      return _Row(
        leading: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTokens.accent,
          ),
        ),
        text: 'Probing through tunnel…',
        color: AppTokens.textSecondary,
      );
    }

    if (latency.failed) {
      return SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppTokens.danger),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tunnel check failed — traffic is not flowing through the proxy',
                style: TextStyle(fontSize: 12, color: AppTokens.danger),
              ),
            ),
            _RefreshButton(),
          ],
        ),
      );
    }

    final ms = latency.ms ?? 0;
    final color = ms < 150
        ? AppTokens.success
        : ms < 400
            ? AppTokens.warning
            : AppTokens.danger;
    return _Row(
      leading: const Icon(Icons.network_ping, size: 16, color: AppTokens.success),
      text: 'Through-tunnel latency $ms ms',
      color: color,
      trailing: _RefreshButton(),
    );
  }
}

class _RefreshButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(tunnelLatencyProvider.notifier).measureNow(),
      borderRadius: BorderRadius.circular(AppTokens.radiusInner),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.refresh, size: 16, color: AppTokens.textSecondary),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.text,
    required this.color,
    this.trailing,
  });

  final Widget leading;
  final String text;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
