// Web-only implementation.
import 'package:web/web.dart' as web;

/// Triggers a browser download for [url].
///
/// Note: The server must allow cross-origin access as needed.
Future<bool> downloadUrl(String url, {String? fileName}) async {
  final a = web.HTMLAnchorElement()
    ..href = url
    ..target = '_blank'
    ..rel = 'noopener';

  if (fileName != null && fileName.trim().isNotEmpty) {
    a.download = fileName;
  } else {
    // Best effort: still triggers navigation which can download depending on content-type.
    a.download = '';
  }

  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  return true;
}
