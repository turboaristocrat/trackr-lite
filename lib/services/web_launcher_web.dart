// Web implementation for direct link triggering
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

bool canWebShare() {
  try {
    return (web.window.navigator as JSObject).has('share');
  } catch (_) {
    return false;
  }
}

Future<bool> triggerWebShare(String title, String text) async {
  try {
    final nav = web.window.navigator;
    final shareData = web.ShareData(
      title: title,
      text: text,
    );
    await nav.share(shareData).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

void openExternalUriDirect(String uri) {
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = uri;
  anchor.target = '_blank';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
