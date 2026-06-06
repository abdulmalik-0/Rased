import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard.dart';

/// Admin-only: describe a service and the AI suggests a docker run / compose.
/// The AI never runs anything — the admin reviews the snippet and copies it.
class DeploySuggestDialog extends ConsumerStatefulWidget {
  const DeploySuggestDialog({super.key});

  @override
  ConsumerState<DeploySuggestDialog> createState() =>
      _DeploySuggestDialogState();
}

class _DeploySuggestDialogState extends ConsumerState<DeploySuggestDialog> {
  final _input = TextEditingController();
  String? _result;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    final desc = _input.text.trim();
    if (desc.isEmpty || _loading) return;
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null || settings.modelName.isEmpty) {
      setState(() => _error = context.tr('configureFirst'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final text = await ref.read(apiProvider).suggestDeploy(
            description: desc,
            aiConfig: settings,
            lang: ref.read(localeProvider).languageCode,
          );
      if (!mounted) return;
      setState(() {
        _result = text;
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
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(Icons.rocket_launch, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(context.tr('deployTitle'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: colors.textSecondary),
                ),
              ]),
              const SizedBox(height: 4),
              Text(context.tr('deployIntro'),
                  style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _input,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _suggest(),
                decoration: InputDecoration(
                  labelText: context.tr('deployHint'),
                  hintText: 'n8n + postgres, uptime-kuma, ...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _suggest,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(context.tr('deploySuggest')),
                  style: FilledButton.styleFrom(backgroundColor: colors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(child: _body(colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(RasedColors colors) {
    if (_error != null) {
      return Text(_error!, style: TextStyle(color: colors.danger));
    }
    if (_loading) {
      return Center(
        child: Text(context.tr('analyzing'),
            style: TextStyle(color: colors.textSecondary)),
      );
    }
    if (_result == null) {
      return Center(
        child: Text(context.tr('deployEmpty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: _result!,
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
              ),
            ),
          ),
        ),
        const Divider(),
        Row(children: [
          Expanded(
            child: Text(context.tr('deployReviewNote'),
                style: TextStyle(fontSize: 11, color: colors.warning)),
          ),
          TextButton.icon(
            onPressed: () => copyToClipboard(context, _result!),
            icon: const Icon(Icons.copy, size: 16),
            label: Text(context.tr('copyAll')),
          ),
        ]),
      ],
    );
  }
}
