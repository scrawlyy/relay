import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../shared/widgets.dart';

/// Session totals row: upload, download, and connection uptime.
class TotalsRow extends StatelessWidget {
  const TotalsRow({
    super.key,
    required this.upTotal,
    required this.downTotal,
    this.connectedSince,
  });

  final int upTotal;
  final int downTotal;
  final DateTime? connectedSince;

  @override
  Widget build(BuildContext context) {
    final uptime = connectedSince == null
        ? null
        : formatUptime(DateTime.now().difference(connectedSince));

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          _Metric(label: 'Uploaded', value: formatBytes(upTotal)),
          _divider(),
          _Metric(label: 'Downloaded', value: formatBytes(downTotal)),
          _divider(),
          _Metric(label: 'Uptime', value: uptime ?? '—'),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: AppTokens.hairline,
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
