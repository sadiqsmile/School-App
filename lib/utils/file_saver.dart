// Cross-platform file saver for binary files.
//
// - On Web: triggers a browser download via data URL.
// - On Android/Desktop: opens a save dialog and writes the file.

import 'file_saver_impl_stub.dart'
    if (dart.library.html) 'file_saver_impl_web.dart'
    if (dart.library.io) 'file_saver_impl_io.dart' as impl;

Future<void> saveFileBytes({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
  String? dialogTitle,
  List<String>? allowedExtensions,
}) {
  return impl.saveFileBytes(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: dialogTitle,
    allowedExtensions: allowedExtensions,
  );
}
