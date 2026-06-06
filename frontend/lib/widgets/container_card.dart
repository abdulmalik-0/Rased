import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'metric_chart.dart';

class ContainerCard extends StatelessWidget {
  final ContainerMetrics container;
  final List<double> cpuHistory;
  final List<double> memoryHistory;
  final VoidCallback onAnalyze;
  final void Function(String action) onAction;
  final bool isAdmin;

  const ContainerCard({
    super.key,
    required this.container,
    required this.cpuHistory,
    required this.memoryHistory,
    required this.onAnalyze,
    required this.onAction,
    this.isAdmin = false,
  });

  Color _statusColor(RasedColors c) {
    switch (container.status) {
      case 'running':
        return c.accent;
      case 'paused':
        return c.warning;
      case 'exited':
      case 'dead':
        return c.danger;
      default:
        return c.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = _statusColor(colors);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    container.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    container.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                _actionsMenu(context, colors),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              container.image,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (container.isRunning) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statChip(colors, context.tr('cpu'),
                      '${container.cpuPercent.toStringAsFixed(1)}%'),
                  _statChip(
                    colors,
                    context.tr('ram'),
                    '${container.memoryPercent.toStringAsFixed(0)}% · '
                        '${container.memoryUsageMb.toStringAsFixed(0)} / '
                        '${container.memoryLimitMb.toStringAsFixed(0)} MB',
                  ),
                  if (container.restartCount > 0)
                    _statChip(colors, context.tr('restarts'),
                        '${container.restartCount}'),
                ],
              ),
              const SizedBox(height: 8),
              MetricChart(
                cpuData: cpuHistory,
                memoryData: memoryHistory,
                title: context.tr('liveUsage'),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAnalyze,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(context.tr('analyzeLogs')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsMenu(BuildContext context, RasedColors colors) {
    return PopupMenuButton<String>(
      tooltip: context.tr('actions'),
      icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 20),
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'logs',
          child: Row(children: [
            const Icon(Icons.terminal, size: 18),
            const SizedBox(width: 8),
            Text(context.tr('viewLogs')),
          ]),
        ),
        if (isAdmin)
          PopupMenuItem(
            value: 'restart',
            child: Row(children: [
              const Icon(Icons.restart_alt, size: 18),
              const SizedBox(width: 8),
              Text(context.tr('restart')),
            ]),
          ),
        if (isAdmin && container.isRunning)
          PopupMenuItem(
            value: 'stop',
            child: Row(children: [
              const Icon(Icons.stop_circle_outlined, size: 18),
              const SizedBox(width: 8),
              Text(context.tr('stop')),
            ]),
          ),
        if (isAdmin && !container.isRunning)
          PopupMenuItem(
            value: 'start',
            child: Row(children: [
              const Icon(Icons.play_circle_outline, size: 18),
              const SizedBox(width: 8),
              Text(context.tr('start')),
            ]),
          ),
      ],
    );
  }

  Widget _statChip(RasedColors colors, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 12, color: colors.textPrimary),
      ),
    );
  }
}
