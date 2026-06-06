import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class AlertsBanner extends StatelessWidget {
  final List<Alert> alerts;

  const AlertsBanner({super.key, required this.alerts});

  IconData _icon(String level) {
    switch (level) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Color _color(String level, RasedColors c) {
    switch (level) {
      case 'critical':
        return c.danger;
      case 'warning':
        return c.warning;
      default:
        return c.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (alerts.isEmpty) return const SizedBox.shrink();

    // Most recent first, de-duplicated by kind:target.
    final seen = <String>{};
    final unique = <Alert>[];
    for (final a in alerts.reversed) {
      final key = '${a.kind}:${a.target}';
      if (seen.add(key)) unique.add(a);
      if (unique.length >= 5) break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active,
                    color: colors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${context.tr('alertsTitle')} (${unique.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final a in unique)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(a.level), color: _color(a.level, colors), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.message,
                        style:
                            TextStyle(fontSize: 12, color: colors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
