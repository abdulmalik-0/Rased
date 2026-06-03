import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class UpsStatusWidget extends StatelessWidget {
  final UpsStatus ups;

  const UpsStatusWidget({super.key, required this.ups});

  @override
  Widget build(BuildContext context) {
    final isOk = ups.connected && !ups.onBattery;
    final icon = !ups.connected
        ? Icons.power_off
        : ups.onBattery
            ? Icons.battery_alert
            : Icons.power;

    final color = !ups.connected
        ? AppTheme.textSecondary
        : ups.onBattery
            ? AppTheme.warning
            : AppTheme.accent;

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
                  const Text(
                    'UPS Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusText,
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                  if (ups.batteryChargePercent != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        value: ups.batteryChargePercent! / 100,
                        backgroundColor: AppTheme.surfaceElevated,
                        color: color,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  if (ups.batteryChargePercent != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Battery: ${ups.batteryChargePercent!.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isOk)
              const Icon(Icons.check_circle, color: AppTheme.accent),
          ],
        ),
      ),
    );
  }

  String get _statusText {
    if (!ups.connected) return ups.error ?? 'NUT disconnected';
    if (ups.onBattery) return 'Running on battery (${ups.status})';
    return 'Connected to mains (${ups.status})';
  }
}
