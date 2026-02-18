import 'dart:convert';

import 'package:csv/csv.dart';

class ExamResultCsvRow {
  const ExamResultCsvRow({
    required this.studentId,
    required this.admissionNo,
    required this.studentName,
    required this.classId,
    required this.sectionId,
    required this.groupId,
    required this.subjectMarks, // Map<subjectName, marks>
    required this.maxMarksPerSubject,
    required this.rowNumber,
  });

  final int rowNumber;
  final String studentId;
  final String admissionNo;
  final String studentName;
  final String classId;
  final String sectionId;
  final String groupId;
  final Map<String, double> subjectMarks;
  final double maxMarksPerSubject; // Assumed same for all subjects

  static List<String> headers({required List<String> subjects}) {
    return [
      'studentId',
      'admissionNo',
      'studentName',
      'class',
      'section',
      'group',
      ...subjects, // Dynamic subject columns
    ];
  }

  Map<String, Object?> toMap() {
    final base = <String, Object?>{
      'studentId': studentId,
      'admissionNo': admissionNo,
      'studentName': studentName,
      'class': classId,
      'section': sectionId,
      'group': groupId,
    };
    // Add subject marks
    for (final entry in subjectMarks.entries) {
      base[entry.key] = entry.value;
    }
    return base;
  }
}

class ExamResultsCsvParseIssue {
  const ExamResultsCsvParseIssue({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;

  @override
  String toString() => 'Row $rowNumber: $message';
}

class ExamResultsCsvParseResult {
  const ExamResultsCsvParseResult({
    required this.rows,
    required this.issues,
    required this.subjects, // Detected subject columns
  });

  final List<ExamResultCsvRow> rows;
  final List<ExamResultsCsvParseIssue> issues;
  final List<String> subjects; // e.g., ['English', 'Math', 'Science']
}

String buildExamResultsCsv({
  required List<Map<String, Object?>> results,
  required List<String> subjects,
}) {
  final headers = ExamResultCsvRow.headers(subjects: subjects);
  final rows = <List<dynamic>>[headers];

  for (final r in results) {
    final row = <dynamic>[];
    for (final h in headers) {
      final val = r[h] ?? '';
      row.add(val);
    }
    rows.add(row);
  }

  return const ListToCsvConverter().convert(rows);
}

ExamResultsCsvParseResult parseExamResultsCsvBytes({
  required List<int> bytes,
  required double maxMarksPerSubject,
}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  return parseExamResultsCsvText(csvText: text, maxMarksPerSubject: maxMarksPerSubject);
}

ExamResultsCsvParseResult parseExamResultsCsvText({
  required String csvText,
  required double maxMarksPerSubject,
}) {
  final issues = <ExamResultsCsvParseIssue>[];

  final converter = CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  );

  List<List<dynamic>> table;
  try {
    table = converter.convert(csvText);
  } catch (e) {
    return ExamResultsCsvParseResult(
      rows: const [],
      issues: [ExamResultsCsvParseIssue(rowNumber: 1, message: 'Invalid CSV: $e')],
      subjects: const [],
    );
  }

  if (table.isEmpty) {
    return const ExamResultsCsvParseResult(
      rows: [],
      issues: [ExamResultsCsvParseIssue(rowNumber: 1, message: 'CSV is empty')],
      subjects: [],
    );
  }

  final header = table.first.map((x) => x.toString().trim()).toList();
  final normalizedHeader = header.map((h) => h.toLowerCase()).toList();

  // Required columns
  final requiredHeaders = ['studentid', 'admissionno', 'studentname', 'class', 'section', 'group'];

  // Build column index map
  final index = <String, int>{};
  for (var i = 0; i < normalizedHeader.length; i++) {
    final h = normalizedHeader[i];
    if (h.isNotEmpty) index[h] = i;
  }

  // Validate required headers
  for (final requiredHeader in requiredHeaders) {
    if (!index.containsKey(requiredHeader)) {
      issues.add(
        ExamResultsCsvParseIssue(
          rowNumber: 1,
          message: 'Missing required column: $requiredHeader',
        ),
      );
    }
  }

  if (issues.isNotEmpty) {
    return ExamResultsCsvParseResult(rows: const [], issues: issues, subjects: const []);
  }

  // Detect subject columns (all non-required columns are subjects)
  final subjectCols = <String>[];
  for (var i = 0; i < header.length; i++) {
    final normalized = normalizedHeader[i];
    if (!requiredHeaders.contains(normalized)) {
      subjectCols.add(header[i]); // Use original case
    }
  }

  if (subjectCols.isEmpty) {
    issues.add(
      ExamResultsCsvParseIssue(
        rowNumber: 1,
        message: 'At least one subject column is required',
      ),
    );
  }

  String cell(List<dynamic> row, String col) {
    final i = index[col.toLowerCase()] ?? -1;
    if (i < 0 || i >= row.length) return '';
    return row[i].toString().trim();
  }

  double cellNum(List<dynamic> row, String col) {
    final s = cell(row, col);
    try {
      return double.parse(s);
    } catch (_) {
      return 0;
    }
  }

  final out = <ExamResultCsvRow>[];

  for (var r = 1; r < table.length; r++) {
    final rowNumber = r + 1; // including header row
    final row = table[r];

    // Skip fully empty rows
    final anyNonEmpty = row.any((x) => x.toString().trim().isNotEmpty);
    if (!anyNonEmpty) continue;

    final studentId = cell(row, 'studentId');
    final admissionNo = cell(row, 'admissionNo');
    final studentName = cell(row, 'studentName');
    final classId = cell(row, 'class');
    final sectionId = cell(row, 'section');
    final groupId = cell(row, 'group');

    if (studentId.isEmpty) {
      issues.add(ExamResultsCsvParseIssue(rowNumber: rowNumber, message: 'Student ID is required'));
      continue;
    }

    if (studentName.isEmpty) {
      issues.add(ExamResultsCsvParseIssue(rowNumber: rowNumber, message: 'Student name is required'));
      continue;
    }

    if (classId.isEmpty) {
      issues.add(ExamResultsCsvParseIssue(rowNumber: rowNumber, message: 'Class is required'));
      continue;
    }

    if (sectionId.isEmpty) {
      issues.add(ExamResultsCsvParseIssue(rowNumber: rowNumber, message: 'Section is required'));
      continue;
    }

    // Parse subject marks
    final subjectMarks = <String, double>{};
    for (final subject in subjectCols) {
      final marks = cellNum(row, subject);
      subjectMarks[subject] = marks;
    }

    out.add(ExamResultCsvRow(
      rowNumber: rowNumber,
      studentId: studentId,
      admissionNo: admissionNo,
      studentName: studentName,
      classId: classId,
      sectionId: sectionId,
      groupId: groupId,
      subjectMarks: subjectMarks,
      maxMarksPerSubject: maxMarksPerSubject,
    ));
  }

  return ExamResultsCsvParseResult(rows: out, issues: issues, subjects: subjectCols);
}
