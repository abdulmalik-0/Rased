// Non-web fallback (this app targets the web; kept for the conditional import).
import 'package:flutter/services.dart';

bool copyText(String text) {
  Clipboard.setData(ClipboardData(text: text));
  return true;
}
