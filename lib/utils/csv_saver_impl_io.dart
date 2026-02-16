import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<void> saveCsvText({
  required String fileName,
  required String csvText,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save CSV',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
  );

  if (path == null || path.trim().isEmpty) {
    // User cancelled.
    return;
  }

  final f = File(path);
  await f.writeAsString(csvText);
}
