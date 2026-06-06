import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class HostStatsWidget extends StatelessWidget {
  final HostStats host;
  final String hostName;

  const HostStatsWidget({super.key, required this.host, required this.hostName});

  Color _barColor(double percent, RasedColors c) {
    if (percent >= 90) return c.danger;
    if (percent >= 75) return c.warning;
    return c.accent;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: colors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  '${context.tr('hostTitle')} · $hostName',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (host.loadAvg1m != null)
                  Text(
                    '${context.tr('load')}: ${host.loadAvg1m!.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!host.available)
              Text(
                host.error ?? context.tr('hostUnavailable'),
                style: TextStyle(color: colors.textSecondary),
              )
            else ...[
              _bar(
                context,
                colors,
                context.tr('hostCpu'),
                host.cpuPercent,
                '${host.cpuPercent.toStringAsFixed(0)}%'
                '${host.cpuCores > 0 ? ' · ${host.cpuCores} ${context.tr('cores')}' : ''}',
              ),
              const SizedBox(height: 10),
              _bar(
                context,
                colors,
                context.tr('hostMemory'),
                host.memoryPercent,
                '${host.memoryPercent.toStringAsFixed(0)}% · '
                    '${(host.memoryUsedMb / 1024).toStringAsFixed(1)} / '
                    '${(host.memoryTotalMb / 1024).toStringAsFixed(1)} GB',
              ),
              for (final disk in host.disks) ...[
                const SizedBox(height: 10),
                _bar(
                  context,
                  colors,
                  '${context.tr('disk')} ${disk.mount}',
                  disk.percent,
                  '${disk.percent.toStringAsFixed(0)}% · '
                      '${disk.usedGb.toStringAsFixed(0)} / '
                      '${disk.totalGb.toStringAsFixed(0)} GB',
                ),
              ],
              if (host.temperatures.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(context.tr('temperatures'),
                    style:
                        TextStyle(fontSize: 12, color: colors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final t in host.temperatures) _tempGauge(colors, t),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Small circular gauge per sensor: ring fills with temperature, the value
  /// sits in the middle, and the sensor label is shown underneath.
  Widget _tempGauge(RasedColors colors, Temp t) {
    final hot = t.high != null ? t.current >= t.high! : t.current >= 80;
    final c = hot
        ? colors.danger
        : (t.current >= 65 ? colors.warning : colors.accent);
    final frac = (t.current / 100).clamp(0.0, 1.0);
    return Tooltip(
      message: '${t.label}: ${t.current.toStringAsFixed(0)}°C',
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      value: frac,
                      strokeWidth: 4,
                      backgroundColor: colors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                    ),
                  ),
                  Text(
                    '${t.current.toStringAsFixed(0)}°',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, color: c),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, RasedColors colors, String label,
      double percent, String trailing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: colors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              trailing,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            backgroundColor: colors.surfaceElevated,
            color: _barColor(percent, colors),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
