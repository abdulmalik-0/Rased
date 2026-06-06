import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class UptimeWidget extends StatelessWidget {
  final List<UptimeResult> results;

  const UptimeWidget({super.key, required this.results});

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
                Icon(Icons.public, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.tr('uptimeTitle'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final r in results) _row(context, colors, r),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, RasedColors colors, UptimeResult r) {
    final color = r.up ? colors.accent : colors.danger;
    final certWarn = r.certExpiryDays != null && r.certExpiryDays! <= 30;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: TextStyle(fontSize: 13, color: colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (r.certExpiryDays != null)
                  Text(
                    context
                        .tr('certExpires')
                        .replaceAll('{days}', '${r.certExpiryDays}'),
                    style: TextStyle(
                      fontSize: 10,
                      color: certWarn ? colors.warning : colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (r.up && r.latencyMs != null)
            Text(
              '${r.latencyMs!.toStringAsFixed(0)} ms',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              r.up ? context.tr('up') : context.tr('down'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
