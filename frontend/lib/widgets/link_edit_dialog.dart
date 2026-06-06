import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

class LinkEditDialog extends ConsumerStatefulWidget {
  final String hostId;
  final String containerName;
  final String url;
  final String label;

  const LinkEditDialog({
    super.key,
    required this.hostId,
    required this.containerName,
    this.url = '',
    this.label = '',
  });

  @override
  ConsumerState<LinkEditDialog> createState() => _LinkEditDialogState();
}

class _LinkEditDialogState extends ConsumerState<LinkEditDialog> {
  late final TextEditingController _url;
  late final TextEditingController _label;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.url);
    _label = TextEditingController(text: widget.label);
  }

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final api = ref.read(apiProvider);
      if (remove || _url.text.trim().isEmpty) {
        await api.deleteLink(widget.hostId, widget.containerName);
      } else {
        await api.setLink(widget.hostId, widget.containerName,
            _url.text.trim(), _label.text.trim());
      }
      ref.invalidate(linksProvider(widget.hostId));
      if (mounted) nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${context.tr('customLink')} — ${widget.containerName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('linkUrl'),
                hintText: 'http://192.168.100.100:8080',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: context.tr('linkLabel'),
                hintText: 'Web UI',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.url.isNotEmpty)
          TextButton(
            onPressed: _saving ? null : () => _save(remove: true),
            child: Text(context.tr('remove')),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: Text(context.tr('save')),
        ),
      ],
    );
  }
}
