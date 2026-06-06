import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class UpsStatusWidget extends StatelessWidget {
  final UpsStatus ups;

  const UpsStatusWidget({super.key, required this.ups});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOk = ups.connected && !ups.onBattery;
    final icon = !ups.connected
        ? Icons.power_off
        : ups.onBattery
            ? Icons.battery_alert
            : Icons.power;

    final color = !ups.connected
        ? colors.textSecondary
        : ups.onBattery
            ? colors.warning
            : colors.accent;

    final charge = ups.batteryChargePercent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('upsStatus'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusText(context),
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                  if (charge != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        value: (charge / 100).clamp(0.0, 1.0),
                        backgroundColor: colors.surfaceElevated,
                        color: color,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  if (charge != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${context.tr('battery')}: ${charge.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isOk) Icon(Icons.check_circle, color: colors.accent),
          ],
        ),
      ),
    );
  }

  String _statusText(BuildContext context) {
    if (!ups.connected) return ups.error ?? context.tr('upsDisconnected');
    if (ups.onBattery) return '${context.tr('onBattery')} (${ups.status})';
    return '${context.tr('onMains')} (${ups.status})';
  }
}
