import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Admin dialog to rename a device/server and configure its UPS (NUT) source.
class DeviceConfigDialog extends ConsumerStatefulWidget {
  final Device device;

  const DeviceConfigDialog({super.key, required this.device});

  @override
  ConsumerState<DeviceConfigDialog> createState() => _DeviceConfigDialogState();
}

class _DeviceConfigDialogState extends ConsumerState<DeviceConfigDialog> {
  late final TextEditingController _name;
  late final TextEditingController _nutHost;
  late final TextEditingController _nutUps;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.device.displayName);
    _nutHost = TextEditingController(text: widget.device.nutHost);
    _nutUps = TextEditingController(text: widget.device.nutUpsName);
  }

  @override
  void dispose() {
    _name.dispose();
    _nutHost.dispose();
    _nutUps.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref.read(apiProvider).updateDevice(
            widget.device.hostId,
            displayName: _name.text.trim(),
            nutHost: _nutHost.text.trim(),
            nutUpsName: _nutUps.text.trim(),
          );
      ref.invalidate(devicesProvider);
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
      title: Text('${context.tr('deviceSettings')} — ${widget.device.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('displayName'),
                hintText: widget.device.hostName,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nutHost,
              decoration: InputDecoration(
                labelText: context.tr('nutHostLabel'),
                hintText: '192.168.100.89',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nutUps,
              decoration: InputDecoration(
                labelText: context.tr('nutUpsLabel'),
                hintText: 'tecnoware',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.tr('save')),
        ),
      ],
    );
  }
}
