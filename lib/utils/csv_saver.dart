// Cross-platform CSV saver.
//
// - On Web: triggers a browser download.
// - On Android/Desktop: opens a save dialog (where supported) and writes the file.
//
// This avoids importing `dart:io` on Web.

import 'csv_saver_impl_stub.dart'
    if (dart.library.html) 'csv_saver_impl_web.dart'
    if (dart.library.io) 'csv_saver_impl_io.dart' as impl;

Future<void> saveCsvText({
  required String fileName,
  required String csvText,
}) {
  return impl.saveCsvText(fileName: fileName, csvText: csvText);
}
