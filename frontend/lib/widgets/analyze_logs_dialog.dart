import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class AnalyzeLogsDialog extends ConsumerStatefulWidget {
  final ContainerMetrics container;

  const AnalyzeLogsDialog({super.key, required this.container});

  @override
  ConsumerState<AnalyzeLogsDialog> createState() => _AnalyzeLogsDialogState();
}

class _AnalyzeLogsDialogState extends ConsumerState<AnalyzeLogsDialog> {
  AnalyzeResult? _result;
  String? _error;
  bool _loading = false;

  Future<void> _analyze() async {
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null || settings.modelName.isEmpty) {
      setState(() {
        _error = 'Configure AI settings first (Settings page).';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await ref.read(backendServiceProvider).analyzeLogs(
            containerId: widget.container.id,
            aiConfig: settings,
          );
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Log Analysis — ${widget.container.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildContent(),
              ),
              if (_result != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Model: ${_result!.modelUsed} • Logs sanitized before analysis',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'Fetching & analyzing logs…',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              'Sensitive data is redacted before sending to AI',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _analyze, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: _result!.analysis,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: AppTheme.textPrimary, height: 1.5),
              code: TextStyle(
                backgroundColor: AppTheme.surfaceElevated,
                color: AppTheme.accent,
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              h1: const TextStyle(color: AppTheme.textPrimary, fontSize: 20),
              h2: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
              h3: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              listBullet: const TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
