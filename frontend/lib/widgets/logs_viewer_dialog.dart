import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class LogsViewerDialog extends ConsumerStatefulWidget {
  final ContainerMetrics container;
  final String apiUrl;

  const LogsViewerDialog({
    super.key,
    required this.container,
    this.apiUrl = '',
  });

  @override
  ConsumerState<LogsViewerDialog> createState() => _LogsViewerDialogState();
}

class _LogsViewerDialogState extends ConsumerState<LogsViewerDialog> {
  List<String>? _lines;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lines = await ref.read(backendServiceProvider).fetchLogs(
            containerId: widget.container.id,
            tail: 200,
            baseUrl: widget.apiUrl,
          );
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.tr('logsTitle')} — ${widget.container.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('refresh'),
                    onPressed: _loading ? null : _load,
                    icon: Icon(Icons.refresh, color: colors.textSecondary),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(child: _buildContent(colors)),
              const SizedBox(height: 8),
              Text(
                context.tr('redactNote'),
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(RasedColors colors) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.danger, size: 40),
            const SizedBox(height: 12),
            Text('${context.tr('logsLoadFailed')}\n$_error',
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    final lines = _lines ?? [];
    if (lines.isEmpty) {
      return Center(
        child: Text(context.tr('noLogs'),
            style: TextStyle(color: colors.textSecondary)),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: SelectableText(
            lines.join('\n'),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
              color: colors.textPrimary,
            ),
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  }
}
