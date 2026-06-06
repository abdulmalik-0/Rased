import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'launch_stub.dart' if (dart.library.js_interop) 'launch_web.dart' as impl;

/// Open [url] in a new browser tab. On Flutter Web we call `window.open`
/// directly and synchronously inside the click handler — the most reliable way.
/// (url_launcher's async path returned false in this deployment.)
void openExternal(BuildContext context, String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !impl.openUrl(url)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${context.tr('cannotOpen')}: $url')),
    );
  }
}
