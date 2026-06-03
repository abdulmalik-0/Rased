import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MetricChart extends StatelessWidget {
  final List<double> cpuData;
  final List<double> memoryData;
  final String title;

  const MetricChart({
    super.key,
    required this.cpuData,
    required this.memoryData,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (cpuData.isEmpty && memoryData.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Collecting data…',
            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppTheme.border.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 50,
                    getTitlesWidget: (value, _) => Text(
                      '${value.toInt()}%',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                _line(cpuData, AppTheme.primary, 'CPU'),
                _line(memoryData, AppTheme.accent, 'RAM'),
              ],
              lineTouchData: const LineTouchData(enabled: false),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _legend(AppTheme.primary, 'CPU'),
            const SizedBox(width: 16),
            _legend(AppTheme.accent, 'RAM'),
          ],
        ),
      ],
    );
  }

  LineChartBarData _line(List<double> data, Color color, String _) {
    return LineChartBarData(
      spots: List.generate(
        data.length,
        (i) => FlSpot(i.toDouble(), data[i].clamp(0, 100)),
      ),
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
