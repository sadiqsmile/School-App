Future<void> saveFileBytes({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
  String? dialogTitle,
  List<String>? allowedExtensions,
}) {
  throw UnsupportedError('File saving is not supported on this platform.');
}
