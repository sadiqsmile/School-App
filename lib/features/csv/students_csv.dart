import 'dart:convert';

import 'package:csv/csv.dart';

class StudentCsvRow {
  const StudentCsvRow({
    required this.studentId,
    required this.admissionNo,
    required this.name,
    required this.classId,
    required this.sectionId,
    required this.groupId,
    required this.parentMobile,
    required this.bloodGroup,
    required this.isActive,
    required this.rowNumber,
    
  });

  /// 1-based row number in the source CSV (including header row).
  final int rowNumber;

  final String studentId;
  final String admissionNo;
  final String name;
  final String classId;
  final String sectionId;
  final String groupId;
  final String parentMobile;
  final String bloodGroup;
  final bool isActive;

  static const headers = <String>[
    'studentId',
    'admissionNo',
    'name',
    'class',
    'section',
    'group',
    'parentMobile',
    'isActive',
  ];

  Map<String, Object?> toMap() {
    return {
      'studentId': studentId,
      'admissionNo': admissionNo,
      'name': name,
      'class': classId,
      'section': sectionId,
      'group': groupId,
      'parentMobile': parentMobile,
      'isActive': isActive,
    };
  }

Map<String, dynamic> toJson() {
  return {
    "admissionNumber": admissionNo,
    "name": name,
    "class": classId,
    "section": sectionId,
    "bloodGroup": bloodGroup,
    "parentPhone": parentMobile,
    "isActive": isActive ? "TRUE" : "FALSE",
  };
}

}



class StudentsCsvParseIssue {
  const StudentsCsvParseIssue({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;

  @override
  String toString() => 'Row $rowNumber: $message';
}

class StudentsCsvParseResult {
  const StudentsCsvParseResult({
    required this.rows,
    required this.issues,
  });

  final List<StudentCsvRow> rows;
  final List<StudentsCsvParseIssue> issues;
}

String buildStudentsCsv({required List<Map<String, Object?>> students}) {
  final rows = <List<dynamic>>[];
  rows.add(StudentCsvRow.headers);

  for (final s in students) {
    final studentId = (s['studentId'] ?? '').toString().trim();
    final admissionNo = (s['admissionNo'] ?? '').toString().trim();
    final name = (s['name'] ?? '').toString().trim();
    final classId = (s['class'] ?? '').toString().trim();
    final sectionId = (s['section'] ?? '').toString().trim();
    final groupId = (s['group'] ?? '').toString().trim();
    final parentMobile = (s['parentMobile'] ?? '').toString().trim();
    final isActive = (s['isActive'] is bool)
        ? (s['isActive'] as bool)
        : (s['isActive']?.toString().toLowerCase() == 'true');

    rows.add([
      studentId,
      admissionNo,
      name,
      classId,
      sectionId,
      groupId,
      parentMobile,
      isActive ? 'true' : 'false',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

StudentsCsvParseResult parseStudentsCsvBytes({required List<int> bytes}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  return parseStudentsCsvText(csvText: text);
}

StudentsCsvParseResult parseStudentsCsvText({required String csvText}) {
  final issues = <StudentsCsvParseIssue>[];

  final converter = CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  );

  List<List<dynamic>> table;
  try {
    table = converter.convert(csvText);
  } catch (e) {
    return StudentsCsvParseResult(
      rows: const [],
      issues: [StudentsCsvParseIssue(rowNumber: 1, message: 'Invalid CSV: $e')],
    );
  }

  if (table.isEmpty) {
    return const StudentsCsvParseResult(
      rows: [],
      issues: [StudentsCsvParseIssue(rowNumber: 1, message: 'CSV is empty')],
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
  for (final requiredHeader in StudentCsvRow.headers) {
    if (!index.containsKey(requiredHeader.toLowerCase())) {
      issues.add(
        StudentsCsvParseIssue(
          rowNumber: 1,
          message: 'Missing required column: $requiredHeader',
        ),
      );
    }
  }

  if (issues.isNotEmpty) {
    return StudentsCsvParseResult(rows: const [], issues: issues);
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

  final out = <StudentCsvRow>[];

  for (var r = 1; r < table.length; r++) {
    final rowNumber = r + 1; // including header row
    final row = table[r];

    // Skip fully empty rows.
    final anyNonEmpty = row.any((x) => x.toString().trim().isNotEmpty);
    if (!anyNonEmpty) continue;

    final studentId = cell(row, 'studentId');
    final admissionNo = cell(row, 'admissionNo');
    final name = cell(row, 'name');
    final classId = cell(row, 'class');
    final sectionId = cell(row, 'section');
    final groupId = cell(row, 'group');
    final parentMobile = cell(row, 'parentMobile');
    final isActiveRaw = cell(row, 'isActive');

    if (name.isEmpty) {
      issues.add(StudentsCsvParseIssue(rowNumber: rowNumber, message: 'Name is required'));
      continue;
    }
    if (admissionNo.isEmpty) {
      issues.add(StudentsCsvParseIssue(rowNumber: rowNumber, message: 'AdmissionNo is required'));
      continue;
    }
    if (classId.isEmpty) {
      issues.add(StudentsCsvParseIssue(rowNumber: rowNumber, message: 'Class is required'));
      continue;
    }
    if (sectionId.isEmpty) {
      issues.add(StudentsCsvParseIssue(rowNumber: rowNumber, message: 'Section is required'));
      continue;
    }
    if (groupId.isEmpty) {
      issues.add(StudentsCsvParseIssue(rowNumber: rowNumber, message: 'Group is required'));
      continue;
    }
    if (parentMobile.length != 10 || int.tryParse(parentMobile) == null) {
      issues.add(StudentsCsvParseIssue(rowNumber: rowNumber, message: 'ParentMobile must be 10 digits'));
      continue;
    }

    out.add(
      StudentCsvRow(
        rowNumber: rowNumber,
        studentId: studentId,
        admissionNo: admissionNo,
        name: name,
        classId: classId,
        sectionId: sectionId,
        groupId: groupId,
        parentMobile: parentMobile,
        bloodGroup: cell(row, 'bloodGroup'),
        isActive: parseBool(isActiveRaw),
      ),
    );
  }

  return StudentsCsvParseResult(rows: out, issues: issues);
}
