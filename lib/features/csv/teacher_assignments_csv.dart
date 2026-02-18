import 'dart:convert';

import 'package:csv/csv.dart';

class TeacherAssignmentCsvRow {
  const TeacherAssignmentCsvRow({
    required this.teacherUid,
    required this.classSectionIds,
    required this.rowNumber,
  });

  /// 1-based row number in the source CSV (including header row).
  final int rowNumber;

  final String teacherUid;
  final List<String> classSectionIds; // comma-separated class/section IDs

  static const headers = <String>[
    'teacherUid',
    'classSectionIds',
  ];

  Map<String, Object?> toMap() {
    return {
      'teacherUid': teacherUid,
      'classSectionIds': classSectionIds.join(','),
    };
  }
}

class TeacherAssignmentsCsvParseIssue {
  const TeacherAssignmentsCsvParseIssue({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;

  @override
  String toString() => 'Row $rowNumber: $message';
}

class TeacherAssignmentsCsvParseResult {
  const TeacherAssignmentsCsvParseResult({
    required this.rows,
    required this.issues,
  });

  final List<TeacherAssignmentCsvRow> rows;
  final List<TeacherAssignmentsCsvParseIssue> issues;
}

String buildTeacherAssignmentsCsv({required List<Map<String, Object?>> assignments}) {
  final rows = <List<dynamic>>[];
  rows.add(TeacherAssignmentCsvRow.headers);

  for (final a in assignments) {
    final teacherUid = (a['teacherUid'] ?? '').toString().trim();
    final classSectionIds = a['classSectionIds'] ?? '';
    final classStr = (classSectionIds is List)
      ? classSectionIds.join(',')
        : classSectionIds.toString().trim();

    rows.add([
      teacherUid,
      classStr,
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

TeacherAssignmentsCsvParseResult parseTeacherAssignmentsCsvBytes({required List<int> bytes}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  return parseTeacherAssignmentsCsvText(csvText: text);
}

TeacherAssignmentsCsvParseResult parseTeacherAssignmentsCsvText({required String csvText}) {
  final issues = <TeacherAssignmentsCsvParseIssue>[];

  final converter = CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  );

  List<List<dynamic>> table;
  try {
    table = converter.convert(csvText);
  } catch (e) {
    return TeacherAssignmentsCsvParseResult(
      rows: const [],
      issues: [TeacherAssignmentsCsvParseIssue(rowNumber: 1, message: 'Invalid CSV: $e')],
    );
  }

  if (table.isEmpty) {
    return const TeacherAssignmentsCsvParseResult(
      rows: [],
      issues: [
        TeacherAssignmentsCsvParseIssue(rowNumber: 1, message: 'CSV is empty'),
      ],
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
  for (final requiredHeader in TeacherAssignmentCsvRow.headers) {
    if (!index.containsKey(requiredHeader.toLowerCase())) {
      issues.add(
        TeacherAssignmentsCsvParseIssue(
          rowNumber: 1,
          message: 'Missing required column: $requiredHeader',
        ),
      );
    }
  }

  if (issues.isNotEmpty) {
    return TeacherAssignmentsCsvParseResult(rows: const [], issues: issues);
  }

  String cell(List<dynamic> row, String col) {
    final i = index[col.toLowerCase()] ?? -1;
    if (i < 0 || i >= row.length) return '';
    return row[i].toString().trim();
  }

  final out = <TeacherAssignmentCsvRow>[];

  for (var r = 1; r < table.length; r++) {
    final rowNumber = r + 1; // including header row
    final row = table[r];

    // Skip fully empty rows.
    final anyNonEmpty = row.any((x) => x.toString().trim().isNotEmpty);
    if (!anyNonEmpty) continue;

    final teacherUid = cell(row, 'teacherUid');
    final classSectionIdsStr = cell(row, 'classSectionIds');

    if (teacherUid.isEmpty) {
      issues.add(
        TeacherAssignmentsCsvParseIssue(
          rowNumber: rowNumber,
          message: 'Teacher UID is required',
        ),
      );
      continue;
    }

    // Parse class/section IDs (comma-separated)
    final classSectionIds = classSectionIdsStr
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    if (classSectionIds.isEmpty) {
      issues.add(
        TeacherAssignmentsCsvParseIssue(
          rowNumber: rowNumber,
          message: 'At least one class/section ID is required',
        ),
      );
      continue;
    }

    out.add(TeacherAssignmentCsvRow(
      rowNumber: rowNumber,
      teacherUid: teacherUid,
      classSectionIds: classSectionIds,
    ));
  }

  return TeacherAssignmentsCsvParseResult(rows: out, issues: issues);
}
