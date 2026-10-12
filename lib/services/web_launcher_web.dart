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

Future<bool> promptPwaInstall() async {
  try {
    final win = web.window as JSObject;
    if (win.has('triggerPwaInstall')) {
      final res = win.callMethod('triggerPwaInstall'.toJS);
      if (res.isA<JSPromise>()) {
        final outcome = await (res as JSPromise).toDart;
        if (outcome.isA<JSBoolean>()) {
          return (outcome as JSBoolean).toDart;
        }
      }
    }
  } catch (_) {}
  return false;
}
