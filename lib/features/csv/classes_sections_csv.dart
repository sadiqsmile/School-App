import 'package:csv/csv.dart';

/// Represents a single class/section row from CSV
class ClassSectionCsvRow {
  const ClassSectionCsvRow({
    required this.classId,
    required this.className,
    required this.classOrder,
    required this.sectionId,
    required this.sectionName,
    required this.sectionOrder,
  });

  final String classId;
  final String className;
  final int classOrder;
  final String sectionId;
  final String sectionName;
  final int sectionOrder;

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'className': className,
      'classOrder': classOrder,
      'sectionId': sectionId,
      'sectionName': sectionName,
      'sectionOrder': sectionOrder,
    };
  }
}

class ClassSectionsCsvParseIssue {
  const ClassSectionsCsvParseIssue({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;
}

class ClassSectionsCsvParseResult {
  const ClassSectionsCsvParseResult({
    required this.rows,
    required this.issues,
  });

  final List<ClassSectionCsvRow> rows;
  final List<ClassSectionsCsvParseIssue> issues;

  bool get hasErrors => issues.isNotEmpty;
}

/// Parse CSV content for classes/sections import
ClassSectionsCsvParseResult parseClassSectionsCsv(String csvContent) {
  final rows = <ClassSectionCsvRow>[];
  final issues = <ClassSectionsCsvParseIssue>[];

  try {
    final parsed = const CsvToListConverter().convert(
      csvContent,
      shouldParseNumbers: false,
    );

    if (parsed.isEmpty) {
      issues.add(const ClassSectionsCsvParseIssue(
        rowNumber: 0,
        message: 'CSV is empty',
      ));
      return ClassSectionsCsvParseResult(rows: rows, issues: issues);
    }

    final header = parsed.first.map((e) => e.toString().trim().toLowerCase()).toList();

    // Expected columns
    final classIdIdx = header.indexOf('classid');
    final classNameIdx = header.indexOf('classname');
    final classOrderIdx = header.indexOf('classorder');
    final sectionIdIdx = header.indexOf('sectionid');
    final sectionNameIdx = header.indexOf('sectionname');
    final sectionOrderIdx = header.indexOf('sectionorder');

    if (classIdIdx == -1 ||
        classNameIdx == -1 ||
        classOrderIdx == -1 ||
        sectionIdIdx == -1 ||
        sectionNameIdx == -1 ||
        sectionOrderIdx == -1) {
      issues.add(const ClassSectionsCsvParseIssue(
        rowNumber: 0,
        message: 'Missing required columns: classId, className, classOrder, '
            'sectionId, sectionName, sectionOrder',
      ));
      return ClassSectionsCsvParseResult(rows: rows, issues: issues);
    }

    for (int i = 1; i < parsed.length; i++) {
      final row = parsed[i];
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue; // Skip empty rows
      }

      try {
        final classId = row[classIdIdx].toString().trim();
        final className = row[classNameIdx].toString().trim();
        final classOrderStr = row[classOrderIdx].toString().trim();
        final sectionId = row[sectionIdIdx].toString().trim();
        final sectionName = row[sectionNameIdx].toString().trim();
        final sectionOrderStr = row[sectionOrderIdx].toString().trim();

        if (classId.isEmpty) {
          issues.add(ClassSectionsCsvParseIssue(
            rowNumber: i + 1,
            message: 'classId is required',
          ));
          continue;
        }

        if (className.isEmpty) {
          issues.add(ClassSectionsCsvParseIssue(
            rowNumber: i + 1,
            message: 'className is required',
          ));
          continue;
        }

        if (sectionId.isEmpty) {
          issues.add(ClassSectionsCsvParseIssue(
            rowNumber: i + 1,
            message: 'sectionId is required',
          ));
          continue;
        }

        final classOrder = int.tryParse(classOrderStr);
        if (classOrder == null) {
          issues.add(ClassSectionsCsvParseIssue(
            rowNumber: i + 1,
            message: 'Invalid classOrder: $classOrderStr',
          ));
          continue;
        }

        final sectionOrder = int.tryParse(sectionOrderStr);
        if (sectionOrder == null) {
          issues.add(ClassSectionsCsvParseIssue(
            rowNumber: i + 1,
            message: 'Invalid sectionOrder: $sectionOrderStr',
          ));
          continue;
        }

        rows.add(ClassSectionCsvRow(
          classId: classId,
          className: className,
          classOrder: classOrder,
          sectionId: sectionId,
          sectionName: sectionName.isEmpty ? sectionId : sectionName,
          sectionOrder: sectionOrder,
        ));
      } catch (e) {
        issues.add(ClassSectionsCsvParseIssue(
          rowNumber: i + 1,
          message: 'Parse error: $e',
        ));
      }
    }
  } catch (e) {
    issues.add(ClassSectionsCsvParseIssue(
      rowNumber: 0,
      message: 'CSV parse error: $e',
    ));
  }

  return ClassSectionsCsvParseResult(rows: rows, issues: issues);
}

/// Generate sample CSV template for classes/sections
String generateClassSectionsCsvTemplate() {
  return 'classId,className,classOrder,sectionId,sectionName,sectionOrder\n'
      'class1,Class 1,1,A,Section A,1\n'
      'class1,Class 1,1,B,Section B,2\n'
      'class2,Class 2,2,A,Section A,1\n';
}
