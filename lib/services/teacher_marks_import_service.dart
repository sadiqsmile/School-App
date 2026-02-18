import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../features/csv/exam_marks_csv.dart';
import '../models/exam_marks_import_result.dart';
import '../models/exam_marks_result.dart';

/// Service for teachers to import marks for their subjects only
/// Teachers can only update marks for their assigned subjects
class TeacherMarksImportService {
  TeacherMarksImportService({FirebaseFirestore? firestore})
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

  /// Parse CSV data for teacher marks import
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
        continue;
      }
    }

    return rows;
  }

  /// Validate teacher CSV rows
  ExamMarksImportPreview validateCsvRows({
    required List<ExamMarksCsvRow> rows,
    required List<String> teacherSubjects,
    required Map<String, int> maxMarksPerSubject,
    required Set<String> validStudentIds,
    required List<String> allowedClassSections, // e.g., ["6_A", "6_B"]
  }) {
    final issues = <String>[];
    final previewRows = <Map<String, Object?>>[];

    for (int i = 0; i < rows.length && i < 5; i++) {
      previewRows.add(rows[i].toMap());
    }

    for (final row in rows) {
      if (row.studentId.isEmpty) {
        issues.add('Row ${row.rowNumber}: studentId is required');
        continue;
      }

      // Check if student is in allowed class/section
      final classSection = '${row.classId}_${row.sectionId}';
      if (!allowedClassSections.contains(classSection)) {
        issues.add(
          'Row ${row.rowNumber}: ${row.name} (${row.classId}/${row.sectionId}) not in your assigned sections',
        );
      }

      if (!validStudentIds.contains(row.studentId)) {
        issues.add('Row ${row.rowNumber}: studentId "${row.studentId}" not found');
      }

      // Validate marks for teacher's subjects only
      for (final subject in teacherSubjects) {
        final mark = row.subjectMarks[subject];
        if (mark != null) {
          final maxMark = maxMarksPerSubject[subject] ?? 0;
          if (mark < 0) {
            issues.add(
              'Row ${row.rowNumber}: ${row.name} - $subject marks cannot be negative',
            );
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
      subjects: teacherSubjects,
      previewRows: previewRows,
      validationIssues: issues,
    );
  }

  /// Import marks for teacher's subject only
  /// Updates only the subject marks, NOT other subjects
  Future<ExamMarksImportReport> importTeacherMarks({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required List<ExamMarksCsvRow> csvRows,
    required List<String> teacherSubjects, // Subjects this teacher can edit
    required Map<String, int> maxMarksPerSubject,
    required String updatedByUid,
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <ExamMarksImportRowResult>[];
    const int batchSize = 400;

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

        final resultRef = _resultsCol(
          schoolId: schoolId,
          yearId: yearId,
          examId: examId,
        ).doc(csvRow.studentId);

        // Get current result to preserve other subject marks
        final currentDoc = await resultRef.get();
        
        Map<String, num> existingMarks = {};
        Map<String, num> existingMaxMarks = {};
        
        if (currentDoc.exists) {
          final data = currentDoc.data() ?? {};
          existingMarks = Map<String, num>.from(data['marks'] ?? {});
          existingMaxMarks = Map<String, num>.from(data['maxMarks'] ?? {});
        }

        // Update only teacher's subject marks
        for (final subject in teacherSubjects) {
          final mark = csvRow.subjectMarks[subject];
          if (mark != null) {
            existingMarks[subject] = mark;
            existingMaxMarks[subject] = maxMarksPerSubject[subject] ?? 0;
          }
        }

        // Recalculate totals
        num total = 0;
        num maxTotal = 0;
        for (final entry in existingMarks.entries) {
          total += entry.value;
        }
        for (final entry in existingMaxMarks.entries) {
          maxTotal += entry.value;
        }

        final percentage = maxTotal > 0 ? (total / maxTotal * 100) : 0;
        final grade = _calculateGrade(percentage);
        final resultStatus = _calculateStatus(percentage);

        // Prepare update data
        final updateData = {
          'marks': existingMarks,
          'maxMarks': existingMaxMarks,
          'total': total,
          'percentage': percentage,
          'grade': grade,
          'resultStatus': resultStatus,
          'updatedAt': Timestamp.now(),
          'updatedByUid': updatedByUid,
        };

        // Use set with merge to preserve other fields
        batch.set(resultRef, updateData, SetOptions(merge: true));
        writesInBatch++;

        results.add(ExamMarksImportRowResult(
          rowNumber: csvRow.rowNumber,
          studentId: csvRow.studentId,
          success: true,
          message: 'Successfully updated',
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

    await commitBatchIfNeeded(force: true);

    final successCount = results.where((r) => r.success).length;
    final failureCount = results.where((r) => !r.success).length;

    return ExamMarksImportReport(
      totalRows: csvRows.length,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
      subjects: teacherSubjects,
    );
  }

  /// Update a single student's marks for a subject
  /// Used for manual editing in the app
  Future<void> updateStudentMarks({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String studentId,
    required Map<String, num> subjectMarks,
    required Map<String, num> maxMarks,
    required String updatedByUid,
  }) async {
    final resultRef = _resultsCol(
      schoolId: schoolId,
      yearId: yearId,
      examId: examId,
    ).doc(studentId);

    // Get current result
    final currentDoc = await resultRef.get();
    if (!currentDoc.exists) {
      throw Exception('Student result not found');
    }

    final data = currentDoc.data() ?? {};
    final existingMarks = Map<String, num>.from(data['marks'] ?? {});
    final existingMaxMarks = Map<String, num>.from(data['maxMarks'] ?? {});

    // Update only provided marks
    existingMarks.addAll(subjectMarks);
    existingMaxMarks.addAll(maxMarks);

    // Recalculate
    num total = 0;
    num maxTotal = 0;
    for (final entry in existingMarks.entries) {
      total += entry.value;
    }
    for (final entry in existingMaxMarks.entries) {
      maxTotal += entry.value;
    }

    final percentage = maxTotal > 0 ? (total / maxTotal * 100) : 0;
    final grade = _calculateGrade(percentage);
    final resultStatus = _calculateStatus(percentage);

    await resultRef.update({
      'marks': existingMarks,
      'maxMarks': existingMaxMarks,
      'total': total,
      'percentage': percentage,
      'grade': grade,
      'resultStatus': resultStatus,
      'updatedAt': Timestamp.now(),
      'updatedByUid': updatedByUid,
    });
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
