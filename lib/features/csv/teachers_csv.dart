import 'dart:convert';

import 'package:csv/csv.dart';

class TeacherCsvRow {
  const TeacherCsvRow({
    required this.teacherUid,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.assignedGroups,
    required this.isActive,
    required this.rowNumber,
  });

  /// 1-based row number in the source CSV (including header row).
  final int rowNumber;

  final String teacherUid;
  final String displayName;
  final String email;
  final String phone;
  final List<String> assignedGroups;
  final bool isActive;

  static const headers = <String>[
    'teacherUid',
    'displayName',
    'email',
    'phone',
    'assignedGroups',
    'isActive',
  ];

  Map<String, Object?> toMap() {
    return {
      'teacherUid': teacherUid,
      'displayName': displayName,
      'email': email,
      'phone': phone,
      'assignedGroups': assignedGroups.join(','),
      'isActive': isActive,
    };
  }
}

class TeachersCsvParseIssue {
  const TeachersCsvParseIssue({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;

  @override
  String toString() => 'Row $rowNumber: $message';
}

class TeachersCsvParseResult {
  const TeachersCsvParseResult({
    required this.rows,
    required this.issues,
  });

  final List<TeacherCsvRow> rows;
  final List<TeachersCsvParseIssue> issues;
}

String buildTeachersCsv({required List<Map<String, Object?>> teachers}) {
  final rows = <List<dynamic>>[];
  rows.add(TeacherCsvRow.headers);

  for (final t in teachers) {
    final teacherUid = (t['teacherUid'] ?? '').toString().trim();
    final displayName = (t['displayName'] ?? '').toString().trim();
    final email = (t['email'] ?? '').toString().trim();
    final phone = (t['phone'] ?? '').toString().trim();
    final assignedGroups = t['assignedGroups'] ?? '';
    final assignedStr = (assignedGroups is List)
        ? assignedGroups.join(',')
        : assignedGroups.toString().trim();
    final isActive = (t['isActive'] is bool)
        ? (t['isActive'] as bool)
        : (t['isActive']?.toString().toLowerCase() == 'true');

    rows.add([
      teacherUid,
      displayName,
      email,
      phone,
      assignedStr,
      isActive ? 'true' : 'false',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

TeachersCsvParseResult parseTeachersCsvBytes({required List<int> bytes}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  return parseTeachersCsvText(csvText: text);
}

TeachersCsvParseResult parseTeachersCsvText({required String csvText}) {
  final issues = <TeachersCsvParseIssue>[];

  final converter = CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  );

  List<List<dynamic>> table;
  try {
    table = converter.convert(csvText);
  } catch (e) {
    return TeachersCsvParseResult(
      rows: const [],
      issues: [TeachersCsvParseIssue(rowNumber: 1, message: 'Invalid CSV: $e')],
    );
  }

  if (table.isEmpty) {
    return const TeachersCsvParseResult(
      rows: [],
      issues: [TeachersCsvParseIssue(rowNumber: 1, message: 'CSV is empty')],
    );
  }

  final header = table.first.map((x) => x.toString().trim()).toList();
  final normalizedHeader = header.map((h) => h.toLowerCase()).toList();

  final index = <String, int>{};
  for (var i = 0; i < normalizedHeader.length; i++) {
    final h = normalizedHeader[i];
    if (h.isNotEmpty) index[h] = i;
  }

  for (final requiredHeader in TeacherCsvRow.headers) {
    if (!index.containsKey(requiredHeader.toLowerCase())) {
      issues.add(
        TeachersCsvParseIssue(
          rowNumber: 1,
          message: 'Missing required column: $requiredHeader',
        ),
      );
    }
  }

  if (issues.isNotEmpty) {
    return TeachersCsvParseResult(rows: const [], issues: issues);
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

  final out = <TeacherCsvRow>[];

  for (var r = 1; r < table.length; r++) {
    final rowNumber = r + 1; // including header row
    final row = table[r];

    final anyNonEmpty = row.any((x) => x.toString().trim().isNotEmpty);
    if (!anyNonEmpty) continue;

    final teacherUid = cell(row, 'teacherUid');
    final displayName = cell(row, 'displayName');
    final email = cell(row, 'email');
    final phone = cell(row, 'phone');
    final assignedGroupsStr = cell(row, 'assignedGroups');
    final isActiveRaw = cell(row, 'isActive');

    if (teacherUid.isEmpty) {
      issues.add(TeachersCsvParseIssue(rowNumber: rowNumber, message: 'Teacher UID is required'));
      continue;
    }
    if (displayName.isEmpty) {
      issues.add(TeachersCsvParseIssue(rowNumber: rowNumber, message: 'Display name is required'));
      continue;
    }
    if (email.isEmpty) {
      issues.add(TeachersCsvParseIssue(rowNumber: rowNumber, message: 'Email is required'));
      continue;
    }

    final assignedGroups = assignedGroupsStr
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    out.add(
      TeacherCsvRow(
        rowNumber: rowNumber,
        teacherUid: teacherUid,
        displayName: displayName,
        email: email,
        phone: phone,
        assignedGroups: assignedGroups,
        isActive: parseBool(isActiveRaw),
      ),
    );
  }

  return TeachersCsvParseResult(rows: out, issues: issues);
}
