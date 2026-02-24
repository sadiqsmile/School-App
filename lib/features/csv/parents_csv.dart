import 'dart:convert';

import 'package:csv/csv.dart';

class ParentCsvRow {
  const ParentCsvRow({
    required this.mobile,
    required this.displayName,
    required this.childrenIds,
    required this.isActive,
    required this.rowNumber,
  });

  /// 1-based row number in the source CSV (including header row).
  final int rowNumber;

  final String mobile;
  final String displayName;
  final List<String> childrenIds; // comma-separated student IDs
  final bool isActive;

  static const headers = <String>[
    'mobile',
    'displayName',
    'childrenIds',
    'isActive',
  ];

  Map<String, Object?> toMap() {
    return {
      'mobile': mobile,
      'displayName': displayName,
      'childrenIds': childrenIds.join(','),
      'isActive': isActive,
    };
  }

Map<String, dynamic> toJson() {
  return {
    "fatherName": displayName,
    "fatherPhone": mobile,
    "isActive": isActive ? "TRUE" : "FALSE",
  };
}

}

class ParentsCsvParseIssue {
  const ParentsCsvParseIssue({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;

  @override
  String toString() => 'Row $rowNumber: $message';
}

class ParentsCsvParseResult {
  const ParentsCsvParseResult({
    required this.rows,
    required this.issues,
  });

  final List<ParentCsvRow> rows;
  final List<ParentsCsvParseIssue> issues;
}

String buildParentsCsv({required List<Map<String, Object?>> parents}) {
  final rows = <List<dynamic>>[];
  rows.add(ParentCsvRow.headers);

  for (final p in parents) {
    final mobile = (p['mobile'] ?? '').toString().trim();
    final displayName = (p['displayName'] ?? '').toString().trim();
    final childrenIds = p['childrenIds'] ?? '';
    final childrenStr = (childrenIds is List)
      ? childrenIds.join(',')
        : childrenIds.toString().trim();
    final isActive = (p['isActive'] is bool)
        ? (p['isActive'] as bool)
        : (p['isActive']?.toString().toLowerCase() == 'true');

    rows.add([
      mobile,
      displayName,
      childrenStr,
      isActive ? 'true' : 'false',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

ParentsCsvParseResult parseParentsCsvBytes({required List<int> bytes}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  return parseParentsCsvText(csvText: text);
}

ParentsCsvParseResult parseParentsCsvText({required String csvText}) {
  final issues = <ParentsCsvParseIssue>[];

  final converter = CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  );

  List<List<dynamic>> table;
  try {
    table = converter.convert(csvText);
  } catch (e) {
    return ParentsCsvParseResult(
      rows: const [],
      issues: [ParentsCsvParseIssue(rowNumber: 1, message: 'Invalid CSV: $e')],
    );
  }

  if (table.isEmpty) {
    return const ParentsCsvParseResult(
      rows: [],
      issues: [ParentsCsvParseIssue(rowNumber: 1, message: 'CSV is empty')],
    );
  }

  final header = table.first.map((x) => x.toString().trim()).toList();
  final normalizedHeader = header.map((h) => h.toLowerCase()).toList();

  // Build column index map.
  final index = <String, int>{};
  for (var i = 0; i < normalizedHeader.length; i++) {
    final h = normalizedHeader[i];
    if (h.isNotEmpty) index[h] = i;
  }

  // Validate required headers.
  for (final requiredHeader in ParentCsvRow.headers) {
    if (!index.containsKey(requiredHeader.toLowerCase())) {
      issues.add(
        ParentsCsvParseIssue(
          rowNumber: 1,
          message: 'Missing required column: $requiredHeader',
        ),
      );
    }
  }

  if (issues.isNotEmpty) {
    return ParentsCsvParseResult(rows: const [], issues: issues);
  }

  String cell(List<dynamic> row, String col) {
    final i = index[col.toLowerCase()] ?? -1;
    if (i < 0 || i >= row.length) return '';
    return row[i].toString().trim();
  }

  bool parseBool(String raw) {
    final v = raw.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes' || v == 'y';
  }

  final out = <ParentCsvRow>[];

  for (var r = 1; r < table.length; r++) {
    final rowNumber = r + 1; // including header row
    final row = table[r];

    // Skip fully empty rows.
    final anyNonEmpty = row.any((x) => x.toString().trim().isNotEmpty);
    if (!anyNonEmpty) continue;

    final mobile = cell(row, 'mobile');
    final displayName = cell(row, 'displayName');
    final childrenIdsStr = cell(row, 'childrenIds');
    final isActiveRaw = cell(row, 'isActive');

    if (mobile.isEmpty) {
      issues.add(ParentsCsvParseIssue(rowNumber: rowNumber, message: 'Mobile is required'));
      continue;
    }

    if (displayName.isEmpty) {
      issues.add(ParentsCsvParseIssue(rowNumber: rowNumber, message: 'Display name is required'));
      continue;
    }

    // Parse children IDs (comma-separated)
    final childrenIds = childrenIdsStr
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    out.add(ParentCsvRow(
      rowNumber: rowNumber,
      mobile: mobile,
      displayName: displayName,
      childrenIds: childrenIds,
      isActive: parseBool(isActiveRaw),
    ));
  }

  return ParentsCsvParseResult(rows: out, issues: issues);
}
