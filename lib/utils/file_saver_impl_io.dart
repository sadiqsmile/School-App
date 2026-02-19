import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<void> saveFileBytes({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
  String? dialogTitle,
  List<String>? allowedExtensions,
}) async {
  final ext = _extensionFromName(fileName);
  final extensions = allowedExtensions ?? (ext.isEmpty ? null : [ext]);

  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle ?? 'Save file',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: extensions,
  );

  if (path == null || path.trim().isEmpty) {
    return;
  }

  final f = File(path);
  await f.writeAsBytes(bytes);
}

String _extensionFromName(String fileName) {
  final idx = fileName.lastIndexOf('.');
  if (idx < 0 || idx == fileName.length - 1) return '';
  return fileName.substring(idx + 1).toLowerCase();
}
