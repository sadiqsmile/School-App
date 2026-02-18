import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../features/csv/exam_results_csv.dart';
import '../models/exam_subject_result.dart';

class ExamResultCsvImportRowResult {
  const ExamResultCsvImportRowResult({
    required this.rowNumber,
    required this.success,
    required this.message,
    this.studentId,
  });

  final int rowNumber;
  final bool success;
  final String message;
  final String? studentId;
}

class ExamResultCsvImportReport {
  const ExamResultCsvImportReport({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<ExamResultCsvImportRowResult> results;
}

class ExamResultCsvImportService {
  ExamResultCsvImportService({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> resultsCol({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
  }) {
    return _yearDoc(schoolId: schoolId, yearId: yearId)
        .collection('exams')
        .doc(examId)
        .collection('results');
  }

  /// Calculate grade based on percentage
  String _calculateGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  /// Export exam results to CSV format
  Future<List<Map<String, Object?>>> exportExamResultsForCsv({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    List<String>? subjects, // If null, detect from first result
  }) async {
    final snap = await resultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .orderBy('studentName')
        .get();

    final results = <Map<String, Object?>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final subjectsData = data['subjects'] as List? ?? [];
      final subjectMarks = <String, double>{};

      for (final s in subjectsData) {
        if (s is Map) {
          final subj = (s['subject'] as String?)?.trim() ?? '';
          final marks = (s['obtainedMarks'] is num) ? (s['obtainedMarks'] as num).toDouble() : 0.0;
          if (subj.isNotEmpty) {
            subjectMarks[subj] = marks;
          }
        }
      }

      results.add({
        'studentId': (data['studentId'] as String?)?.trim() ?? doc.id,
        'admissionNo': (data['admissionNo'] as String?)?.trim() ?? '',
        'studentName': (data['studentName'] as String?)?.trim() ?? '',
        'class': (data['class'] as String?)?.trim() ?? '',
        'section': (data['section'] as String?)?.trim() ?? '',
        'group': (data['groupId'] as String?)?.trim() ?? '',
        ...subjectMarks,
      });
    }

    return results;
  }

  /// Import exam results from CSV
  /// Returns detailed report with success/failure counts
  Future<ExamResultCsvImportReport> importExamResults({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required List<ExamResultCsvRow> rows,
    required List<String> subjects, // Subject names (e.g., ['English', 'Math'])
    required double maxMarksPerSubject,
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <ExamResultCsvImportRowResult>[];

    final resultsColRef = resultsCol(schoolId: schoolId, yearId: yearId, examId: examId);

    const maxWritesPerBatch = 400;
    WriteBatch batch = _firestore.batch();
    var writesInBatch = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (writesInBatch == 0) return;
      if (!force && writesInBatch < maxWritesPerBatch) return;
      await batch.commit();
      batch = _firestore.batch();
      writesInBatch = 0;
    }

    int done = 0;

    for (final r in rows) {
      try {
        final cleanedStudentId = r.studentId.trim();
        final cleanedStudentName = r.studentName.trim();
        final cleanedClass = r.classId.trim();
        final cleanedSection = r.sectionId.trim();

        if (cleanedStudentId.isEmpty) {
          results.add(ExamResultCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Student ID is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        if (cleanedStudentName.isEmpty) {
          results.add(ExamResultCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Student name is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        // Build subject results
        final subjectResults = <ExamSubjectResult>[];
        double totalObtained = 0;
        double totalMax = 0;

        for (final subjectName in subjects) {
          final obtainedMarks = r.subjectMarks[subjectName] ?? 0.0;
          subjectResults.add(ExamSubjectResult(
            subject: subjectName,
            maxMarks: maxMarksPerSubject,
            obtainedMarks: obtainedMarks,
          ));
          totalObtained += obtainedMarks;
          totalMax += maxMarksPerSubject;
        }

        // Calculate percentage and grade
        final percentage = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;
        final grade = _calculateGrade(percentage);

        // Prepare document data
        final docRef = resultsColRef.doc(cleanedStudentId);
        batch.set(
          docRef,
          {
            'studentId': cleanedStudentId,
            'admissionNo': (r.admissionNo.trim().isNotEmpty) ? r.admissionNo.trim() : null,
            'studentName': cleanedStudentName,
            'class': cleanedClass,
            'section': cleanedSection,
            'groupId': r.groupId.trim(),
            'subjects': subjectResults.map((s) => s.toMap()).toList(),
            'total': totalObtained,
            'percentage': percentage,
            'grade': grade,
            'isPublished': false, // New results are not published by default
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        writesInBatch++;

        results.add(ExamResultCsvImportRowResult(
          rowNumber: r.rowNumber,
          success: true,
          message: 'OK - $grade (${percentage.toStringAsFixed(1)}%)',
          studentId: cleanedStudentId,
        ));

        done++;
        onProgress?.call(done, rows.length);

        await commitBatchIfNeeded();
      } catch (e) {
        results.add(ExamResultCsvImportRowResult(
          rowNumber: r.rowNumber,
          success: false,
          message: 'Error: $e',
        ));
        done++;
        onProgress?.call(done, rows.length);
      }
    }

    await commitBatchIfNeeded(force: true);

    final successCount = results.where((x) => x.success).length;
    final failureCount = results.where((x) => !x.success).length;

    return ExamResultCsvImportReport(
      totalRows: rows.length,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
    );
  }
}
