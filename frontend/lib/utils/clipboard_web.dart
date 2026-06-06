// Web clipboard that works on http:// (non-secure) contexts.
// Uses a hidden <textarea> + document.execCommand('copy'), which does not
// require the secure-context navigator.clipboard API.
import 'package:web/web.dart' as web;

bool copyText(String text) {
  try {
    final ta =
        web.document.createElement('textarea') as web.HTMLTextAreaElement;
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.setProperty('position', 'fixed');
    ta.style.setProperty('left', '-9999px');
    ta.style.setProperty('opacity', '0');
    web.document.body?.appendChild(ta);
    ta.focus();
    ta.select();
    final ok = web.document.execCommand('copy');
    ta.remove();
    return ok;
  } catch (_) {
    return false;
  }
}
