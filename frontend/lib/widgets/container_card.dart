import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'metric_chart.dart';

class ContainerCard extends StatelessWidget {
  final ContainerMetrics container;
  final List<double> cpuHistory;
  final List<double> memoryHistory;
  final VoidCallback onAnalyze;

  const ContainerCard({
    super.key,
    required this.container,
    required this.cpuHistory,
    required this.memoryHistory,
    required this.onAnalyze,
  });

  Color get _statusColor {
    switch (container.status) {
      case 'running':
        return AppTheme.accent;
      case 'paused':
        return AppTheme.warning;
      case 'exited':
      case 'dead':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    container.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    container.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              container.image,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (container.isRunning) ...[
              Row(
                children: [
                  _statChip('CPU', '${container.cpuPercent.toStringAsFixed(1)}%'),
                  const SizedBox(width: 8),
                  _statChip(
                    'RAM',
                    '${container.memoryUsageMb.toStringAsFixed(0)} / '
                    '${container.memoryLimitMb.toStringAsFixed(0)} MB',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MetricChart(
                cpuData: cpuHistory,
                memoryData: memoryHistory,
                title: 'Live Usage',
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAnalyze,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Analyze Logs'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
      ),
    );
  }
}
