import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';

import '../config/app_config.dart';
import '../features/csv/exam_marks_csv.dart';
import '../models/exam_marks_import_result.dart';
import '../models/exam_marks_result.dart';

/// Service for admin to import/export exam marks
/// Handles both CSV operations and Firestore persistence
class ExamMarksImportService {
  ExamMarksImportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  DocumentReference<Map<String, dynamic>> _yearDoc({
    String schoolId = AppConfig.schoolId,
    required String yearId,
  }) {
    return _schoolDoc(schoolId: schoolId).collection('academicYears').doc(yearId);
  }

  CollectionReference<Map<String, dynamic>> _resultsCol({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
  }) {
    return _yearDoc(schoolId: schoolId, yearId: yearId)
        .collection('exams')
        .doc(examId)
        .collection('results');
  }

  /// Parse CSV data to ExamMarksCsvRow list
  List<ExamMarksCsvRow> parseCsvData({
    required List<List<dynamic>> csvData,
    required List<String> subjects,
  }) {
    if (csvData.isEmpty) return [];

    final headers = csvData[0].cast<String>();
    final rows = <ExamMarksCsvRow>[];

    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty) continue;

      try {
        final map = <String, dynamic>{};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          map[headers[j]] = row[j];
        }

        final subjectMarks = <String, num>{};
        for (final subject in subjects) {
          final mark = map[subject];
          if (mark != null) {
            final markNum = _parseNum(mark);
            if (markNum != null) {
              subjectMarks[subject] = markNum;
            }
          }
        }

        rows.add(ExamMarksCsvRow(
          rowNumber: i + 1,
          studentId: (map['studentId'] as String?)?.trim() ?? '',
          admissionNo: (map['admissionNo'] as dynamic)?.toString().trim(),
          name: (map['name'] as String?)?.trim() ?? '',
          classId: (map['classId'] as String?)?.trim() ?? '',
          sectionId: (map['sectionId'] as String?)?.trim() ?? '',
          groupId: (map['groupId'] as String?)?.trim() ?? '',
          studentType: (map['studentType'] as dynamic)?.toString().trim(),
          subjectMarks: subjectMarks,
        ));
      } catch (e) {
        // Skip invalid rows
        continue;
      }
    }

    return rows;
  }

  /// Generate CSV template for exam marks
  String generateCsvTemplate({
    required List<ExamMarksCsvRow> students,
    required List<String> subjects,
  }) {
    final rows = <List<String>>[];
    
    // Header row
    rows.add(ExamMarksCsvRow.headers(subjects: subjects));

    // Data rows
    for (final student in students) {
      final row = <String>[];
      row.add(student.studentId);
      row.add(student.admissionNo ?? '');
      row.add(student.name);
      row.add(student.classId);
      row.add(student.sectionId);
      row.add(student.groupId);
      row.add(student.studentType ?? '');
      
      for (final subject in subjects) {
        row.add(student.subjectMarks[subject]?.toString() ?? '');
      }
      
      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Validate CSV rows before import
  ExamMarksImportPreview validateCsvRows({
    required List<ExamMarksCsvRow> rows,
    required List<String> subjects,
    required Map<String, int> maxMarksPerSubject,
    required Set<String> validStudentIds,
  }) {
    final issues = <String>[];
    final previewRows = <Map<String, Object?>>[];

    for (int i = 0; i < rows.length && i < 5; i++) {
      previewRows.add(rows[i].toMap());
    }

    // Validate each row
    for (final row in rows) {
      if (row.studentId.isEmpty) {
        issues.add('Row ${row.rowNumber}: studentId is required');
        continue;
      }

      if (!validStudentIds.contains(row.studentId)) {
        issues.add('Row ${row.rowNumber}: studentId "${row.studentId}" not found');
      }

      // Validate marks
      for (final subject in subjects) {
        final mark = row.subjectMarks[subject];
        if (mark != null) {
          final maxMark = maxMarksPerSubject[subject] ?? 0;
          if (mark < 0) {
            issues.add('Row ${row.rowNumber}: ${row.name} - $subject marks cannot be negative');
          }
          if (mark > maxMark && maxMark > 0) {
            issues.add(
              'Row ${row.rowNumber}: ${row.name} - $subject marks ($mark) exceeds max ($maxMark)',
            );
          }
        }
      }
    }

    return ExamMarksImportPreview(
      totalRows: rows.length,
      subjects: subjects,
      previewRows: previewRows,
      validationIssues: issues,
    );
  }

  /// Import exam marks from CSV rows
  /// Returns report of success/failure per row
  Future<ExamMarksImportReport> importExamMarks({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String examName,
    required List<ExamMarksCsvRow> csvRows,
    required List<String> subjects,
    required Map<String, int> maxMarksPerSubject,
    required String updatedByUid,
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <ExamMarksImportRowResult>[];
    const int batchSize = 400; // Firestore write limit

    WriteBatch batch = _firestore.batch();
    int writesInBatch = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (writesInBatch == 0) return;
      if (!force && writesInBatch < batchSize) return;
      await batch.commit();
      batch = _firestore.batch();
      writesInBatch = 0;
    }

    int done = 0;

    for (final csvRow in csvRows) {
      try {
        if (csvRow.studentId.isEmpty) {
          results.add(ExamMarksImportRowResult(
            rowNumber: csvRow.rowNumber,
            studentId: '',
            success: false,
            message: 'studentId is required',
          ));
          done++;
          onProgress?.call(done, csvRows.length);
          continue;
        }

        // Calculate totals
        num total = 0;
        num maxTotal = 0;
        final marks = <String, num>{};
        final maxMarks = <String, num>{};

        for (final subject in subjects) {
          final mark = csvRow.subjectMarks[subject] ?? 0;
          final maxMark = maxMarksPerSubject[subject] ?? 0;

          marks[subject] = mark;
          maxMarks[subject] = maxMark;
          total += mark;
          maxTotal += maxMark;
        }

        final percentage = maxTotal > 0 ? (total / maxTotal * 100) : 0;
        final grade = _calculateGrade(percentage);
        final resultStatus = _calculateStatus(percentage);

        // Create/update result document
        final resultRef = _resultsCol(
          schoolId: schoolId,
          yearId: yearId,
          examId: examId,
        ).doc(csvRow.studentId);

        final resultData = ExamMarksResult(
          studentId: csvRow.studentId,
          admissionNo: csvRow.admissionNo,
          name: csvRow.name,
          classId: csvRow.classId,
          sectionId: csvRow.sectionId,
          groupId: csvRow.groupId,
          examId: examId,
          examName: examName,
          marks: marks,
          maxMarks: maxMarks,
          total: total,
          percentage: percentage,
          grade: grade,
          resultStatus: resultStatus,
          updatedAt: DateTime.now(),
          updatedByUid: updatedByUid,
          studentType: csvRow.studentType,
        );

        batch.set(resultRef, resultData.toFirestore());
        writesInBatch++;

        results.add(ExamMarksImportRowResult(
          rowNumber: csvRow.rowNumber,
          studentId: csvRow.studentId,
          success: true,
          message: 'Successfully imported',
          studentName: csvRow.name,
        ));

        await commitBatchIfNeeded();
      } catch (e) {
        results.add(ExamMarksImportRowResult(
          rowNumber: csvRow.rowNumber,
          studentId: csvRow.studentId,
          success: false,
          message: 'Error: ${e.toString()}',
        ));
      }

      done++;
      onProgress?.call(done, csvRows.length);
    }

    // Commit remaining writes
    await commitBatchIfNeeded(force: true);

    final successCount = results.where((r) => r.success).length;
    final failureCount = results.where((r) => !r.success).length;

    return ExamMarksImportReport(
      totalRows: csvRows.length,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
      subjects: subjects,
    );
  }

  /// Export exam marks for a specific class/section
  Future<String> exportExamMarksForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required List<String> subjects,
  }) async {
    final snap = await _resultsCol(
      schoolId: schoolId,
      yearId: yearId,
      examId: examId,
    )
        .where('classId', isEqualTo: classId)
        .where('sectionId', isEqualTo: sectionId)
        .orderBy('name')
        .get();

    final csvRows = snap.docs
        .asMap()
        .entries
        .map((e) {
          final result = ExamMarksResult.fromDoc(
            e.value as DocumentSnapshot<Map<String, dynamic>>,
          );
          return ExamMarksCsvRow.fromExamMarksResult(
            result,
            subjects: subjects,
            rowNumber: e.key + 1,
          );
        })
        .toList(growable: false);

    return generateCsvTemplate(students: csvRows, subjects: subjects);
  }

  num? _parseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value.trim());
    }
    return null;
  }

  String _calculateGrade(num percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  String _calculateStatus(num percentage) {
    return percentage >= 40 ? 'pass' : 'fail';
  }
}
