// Web implementation for direct link triggering
import 'package:web/web.dart' as web;

void openExternalUriDirect(String uri) {
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = uri;
  anchor.target = '_blank';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
