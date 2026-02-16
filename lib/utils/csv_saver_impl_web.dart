import 'package:web/web.dart' as web;

Future<void> saveCsvText({
  required String fileName,
  required String csvText,
}) async {
  // Use a data: URL so we don't need to touch `dart:html` or JS Blob interop.
  // This is reliable for small/medium CSV exports.
  final encoded = Uri.encodeComponent(csvText);
  final href = 'data:text/csv;charset=utf-8,$encoded';

  final a = web.HTMLAnchorElement()
    ..href = href
    ..download = fileName;

  web.document.body?.appendChild(a);
  a.click();
  a.remove();
}
