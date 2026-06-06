import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(historyProvider);
    final range = ref.watch(historyRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('historyTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(historyProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 24, label: Text(context.tr('rangeDay'))),
                ButtonSegment(value: 168, label: Text(context.tr('rangeWeek'))),
                ButtonSegment(value: 720, label: Text(context.tr('rangeMonth'))),
              ],
              selected: {range},
              onSelectionChanged: (s) =>
                  ref.read(historyRangeProvider.notifier).state = s.first,
            ),
          ),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${context.tr('historyError')}: $e',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (points) {
                if (points.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.tr('noHistory'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('hostCpuMem'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(height: 280, child: _chart(points, colors)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _legend(
                                  colors.primary, context.tr('hostCpu'), colors),
                              const SizedBox(width: 16),
                              _legend(colors.accent, context.tr('hostMemory'),
                                  colors),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chart(List<HistoryPoint> points, RasedColors colors) {
    List<FlSpot> series(double? Function(HistoryPoint) sel) {
      final spots = <FlSpot>[];
      for (var i = 0; i < points.length; i++) {
        final v = sel(points[i]);
        if (v != null) spots.add(FlSpot(i.toDouble(), v.clamp(0, 100)));
      }
      return spots;
    }

    final spanHours =
        points.last.ts.difference(points.first.ts).inHours.abs();
    final fmt = spanHours <= 36 ? DateFormat('HH:mm') : DateFormat('MM/dd');
    final labelInterval = (points.length / 6).ceil().clamp(1, 9999).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
              color: colors.border.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 25,
              getTitlesWidget: (value, _) => Text('${value.toInt()}%',
                  style: TextStyle(fontSize: 10, color: colors.textSecondary)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labelInterval,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(fmt.format(points[i].ts),
                      style: TextStyle(
                          fontSize: 9, color: colors.textSecondary)),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _line(series((p) => p.hostCpu), colors.primary),
          _line(series((p) => p.hostMem), colors.accent),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData:
          BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
    );
  }

  Widget _legend(Color color, String label, RasedColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      ],
    );
  }
}
