import 'package:excel/excel.dart';

List<List<dynamic>> parseExcelTableFromBytes(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return const [];

  final sheetName = excel.tables.keys.first;
  final sheet = excel.tables[sheetName];
  if (sheet == null) return const [];

  return sheet.rows
      .map((row) => row.map((cell) => _cellValue(cell?.value)).toList())
      .toList();
}

List<int> buildExcelFileBytes({
  required List<String> headers,
  required List<List<Object?>> rows,
  String sheetName = 'Sheet1',
}) {
  final excel = Excel.createExcel();
  final sheet = excel[sheetName];

  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
  for (final row in rows) {
    sheet.appendRow(row.map((cell) => TextCellValue(cell?.toString() ?? '')).toList());
  }

  excel.setDefaultSheet(sheetName);

  return excel.encode() ?? <int>[];
}

Object _cellValue(Object? value) {
  if (value == null) return '';
  return value;
}
