import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../screens/chat_screen.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard.dart';

class AnalyzeLogsDialog extends ConsumerStatefulWidget {
  final ContainerMetrics container;
  final String apiUrl;
  final String hostId;

  const AnalyzeLogsDialog({
    super.key,
    required this.container,
    this.apiUrl = '',
    this.hostId = 'default',
  });

  @override
  ConsumerState<AnalyzeLogsDialog> createState() => _AnalyzeLogsDialogState();
}

class _AnalyzeLogsDialogState extends ConsumerState<AnalyzeLogsDialog> {
  AnalyzeResult? _result;
  String? _error;
  bool _loading = false;
  bool _started = false;
  bool _saved = false;
  String? _chatId;

  Future<void> _analyze() async {
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null || settings.modelName.isEmpty) {
      setState(() {
        _started = true;
        _error = context.tr('configureFirst');
      });
      return;
    }

    setState(() {
      _started = true;
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await ref.read(apiProvider).analyzeLogs(
            containerId: widget.container.id,
            aiConfig: settings,
            baseUrl: widget.apiUrl,
            lang: ref.read(localeProvider).languageCode,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
      _saveAnalysis(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveAnalysis(AnalyzeResult result) async {
    try {
      final id = await ref.read(apiProvider).upsertChat(
        hostId: widget.hostId,
        title: '🔍 ${widget.container.name}',
        messages: [
          {'role': 'user', 'content': 'Analyze logs: ${widget.container.name}'},
          {'role': 'assistant', 'content': result.analysis},
        ],
      );
      if (mounted) setState(() {
        _saved = true;
        _chatId = id;
      });
    } catch (_) {}
  }

  void _copyAll() {
    if (_result == null) return;
    copyToClipboard(context, _result!.analysis);
  }

  void _continueInChat() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        hostId: widget.hostId,
        apiUrl: widget.apiUrl,
        initialChatId: _chatId,
        initialMessages: _result == null
            ? null
            : [
                {
                  'role': 'user',
                  'content': 'Analyze logs: ${widget.container.name}'
                },
                {'role': 'assistant', 'content': _result!.analysis},
              ],
      ),
    ));
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
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.tr('aiLogAnalysis')} — ${widget.container.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(child: _buildContent(colors)),
              if (_result != null) ...[
                const Divider(),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _copyAll,
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(context.tr('copyAll')),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _continueInChat,
                      icon: const Icon(Icons.forum_outlined, size: 16),
                      label: Text(context.tr('continueInChat')),
                      style:
                          FilledButton.styleFrom(backgroundColor: colors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${context.tr('modelLabel')}: ${_result!.modelUsed} • '
                  '${context.tr('sanitizedNote')}'
                  '${_saved ? ' • ${context.tr('analysisSaved')}' : ''}',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(RasedColors colors) {
    if (!_started) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: colors.primary, size: 40),
            const SizedBox(height: 12),
            Text(
              context.tr('analyzeIntro'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.play_arrow),
              label: Text(context.tr('startAnalysis')),
              style: FilledButton.styleFrom(backgroundColor: colors.primary),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: 16),
            Text(
              context.tr('analyzing'),
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('redactNote'),
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
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
            Icon(Icons.error_outline, color: colors.danger, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _analyze,
              child: Text(context.tr('retry')),
            ),
          ],
        ),
      );
    }

    if (_result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: MarkdownBody(
        data: _result!.analysis,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: colors.textPrimary, height: 1.5),
          code: TextStyle(
            backgroundColor: colors.surfaceElevated,
            color: colors.accent,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          h1: TextStyle(color: colors.textPrimary, fontSize: 20),
          h2: TextStyle(color: colors.textPrimary, fontSize: 18),
          h3: TextStyle(color: colors.textPrimary, fontSize: 16),
          listBullet: TextStyle(color: colors.primary),
        ),
      ),
    );
  }
}
