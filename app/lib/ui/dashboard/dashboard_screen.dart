import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../providers/connection_providers.dart';
import '../../providers/profiles_providers.dart';
import '../../providers/throughput_provider.dart';
import '../shared/widgets.dart';
import 'widgets/latency_pill.dart';
import 'widgets/status_card.dart';
import 'widgets/throughput_chart.dart';
import 'widgets/totals_row.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final throughput = ref.watch(throughputProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space,
                  AppTokens.space,
                  AppTokens.space,
                  0,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Relay',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppTokens.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (activeProfile != null)
                      AppPill(
                        label: activeProfile.name,
                        icon: Icons.alt_route,
                        color: AppTokens.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatusCard(connection: connection),
                    const SizedBox(height: AppTokens.space),
                    LatencyPill(connection: connection),
                    const SizedBox(height: AppTokens.space),
                    ThroughputChart(points: throughput.points),
                    const SizedBox(height: AppTokens.space),
                    TotalsRow(
                      upTotal: throughput.upTotal,
                      downTotal: throughput.downTotal,
                      connectedSince: connection.connectedSince,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: AppTokens.dockClearance(context)),
            ),
          ],
        ),
      ),
    );
  }
}
