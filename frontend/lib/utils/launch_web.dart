// Web implementation: open a new tab via the browser's window.open.
import 'package:web/web.dart' as web;

bool openUrl(String url) {
  try {
    web.window.open(url, '_blank');
    return true;
  } catch (_) {
    return false;
  }
}
