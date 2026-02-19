import 'dart:convert';

import 'package:web/web.dart' as web;

Future<void> saveFileBytes({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
  String? dialogTitle,
  List<String>? allowedExtensions,
}) async {
  final encoded = base64Encode(bytes);
  final href = 'data:$mimeType;base64,$encoded';

  final a = web.HTMLAnchorElement()
    ..href = href
    ..download = fileName;

  web.document.body?.appendChild(a);
  a.click();
  a.remove();
}
