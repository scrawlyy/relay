import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../providers/throughput_provider.dart';
import '../../shared/widgets.dart';

/// Live up/down throughput sparkline over the last 60 seconds.
class ThroughputChart extends StatelessWidget {
  const ThroughputChart({super.key, required this.points});

  final List<ThroughputPoint> points;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Throughput',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppTokens.textPrimary,
                ),
              ),
              Spacer(),
              _LegendDot(color: AppTokens.accent, label: 'Up'),
              SizedBox(width: 12),
              _LegendDot(color: AppTokens.success, label: 'Down'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: points.isEmpty
                ? const _IdlePlaceholder()
                : LineChart(_chart(points)),
          ),
          const SizedBox(height: 4),
          _XAxisLabels(),
        ],
      ),
    );
  }

  LineChartData _chart(List<ThroughputPoint> points) {
    final spotsUp = <FlSpot>[];
    final spotsDown = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spotsUp.add(FlSpot(i.toDouble(), points[i].upRate.toDouble()));
      spotsDown.add(FlSpot(i.toDouble(), points[i].downRate.toDouble()));
    }

    final maxY = [
      ...spotsUp.map((s) => s.y),
      ...spotsDown.map((s) => s.y),
      1024.0,
    ].reduce((a, b) => a > b ? a : b);

    return LineChartData(
      minX: 0,
      maxX: (points.length - 1).toDouble().clamp(1, double.infinity),
      minY: 0,
      maxY: maxY * 1.15,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppTokens.hairline,
          strokeWidth: 1,
        ),
      ),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        _series(spotsUp, AppTokens.accent),
        _series(spotsDown, AppTokens.success),
      ],
    );
  }

  LineChartBarData _series(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      barWidth: 2,
      color: color,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _IdlePlaceholder extends StatelessWidget {
  const _IdlePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Connect to see live traffic',
        style: TextStyle(
          fontSize: 12,
          color: AppTokens.textTertiary.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTokens.textSecondary),
        ),
      ],
    );
  }
}

class _XAxisLabels extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '60s',
            style: TextStyle(
              fontSize: 10,
              color: AppTokens.textTertiary.withValues(alpha: 0.7),
            ),
          ),
          Text(
            'now',
            style: TextStyle(
              fontSize: 10,
              color: AppTokens.textTertiary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
