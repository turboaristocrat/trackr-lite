// Web implementation using package:web or universal JS
import 'dart:convert';
import 'package:web/web.dart' as web;

void triggerBrowserDownload(String content, String fileName) {
  final bytes = utf8.encode(content);
  // Create data URI for instant, robust universal download
  final base64Content = base64Encode(bytes);
  final dataUri = 'data:application/json;charset=utf-8;base64,$base64Content';

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = dataUri;
  anchor.download = fileName;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
