import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'clipboard_stub.dart' if (dart.library.js_interop) 'clipboard_web.dart'
    as impl;

/// Copy [text] to the clipboard and show a snackbar. Works over plain HTTP too:
/// on web it uses a <textarea> + execCommand fallback, because the async
/// Clipboard API (navigator.clipboard) is only available in secure contexts
/// (HTTPS or localhost) — not on http://192.168.x.x.
void copyToClipboard(BuildContext context, String text) {
  final ok = impl.copyText(text);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ok ? context.tr('copied') : context.tr('copyFailed'))),
  );
}
