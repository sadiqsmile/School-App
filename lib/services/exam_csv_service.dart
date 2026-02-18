import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';

import '../config/app_config.dart';
import '../models/exam_schedule_item.dart';
import '../models/exam_subject_result.dart';

/// Result of a CSV row import attempt
class ExamResultsCsvRowResult {
  const ExamResultsCsvRowResult({
    required this.rowNumber,
    required this.studentId,
    required this.success,
    required this.message,
  });

  final int rowNumber;
  final String studentId;
  final bool success;
  final String message;
}

/// Summary of import operation
class ExamResultsCsvImportSummary {
  const ExamResultsCsvImportSummary({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<ExamResultsCsvRowResult> results;
}

class ExamCsvService {
  ExamCsvService({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> _examResultsCol({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
  }) {
    return _yearDoc(schoolId: schoolId, yearId: yearId)
        .collection('exams')
        .doc(examId)
        .collection('results');
  }

  CollectionReference<Map<String, dynamic>> _examTimetableCol({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
  }) {
    return _yearDoc(schoolId: schoolId, yearId: yearId)
        .collection('exams')
        .doc(examId)
        .collection('timetable');
  }

  /// Get students for a class-section with their base data
  Future<List<Map<String, dynamic>>> _getStudentsForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String classId,
    required String sectionId,
  }) async {
    final snap = await _yearDoc(schoolId: schoolId, yearId: yearId)
        .collection('students')
        .where('class', isEqualTo: classId.trim())
        .where('section', isEqualTo: sectionId.trim())
        .get();

    final students = <Map<String, dynamic>>[];
    
    // Fetch base student data for each year-student
    for (final yearStudentDoc in snap.docs) {
      final yearStudentData = yearStudentDoc.data();
      final studentId = yearStudentData['studentId'] as String?;
      
      if (studentId == null || studentId.isEmpty) continue;
      
      // Fetch base student data
      try {
        final baseDoc = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .doc(studentId)
            .get();
        
        if (baseDoc.exists) {
          final baseData = baseDoc.data() ?? <String, dynamic>{};
          students.add({
            'studentId': studentId,
            'admissionNo': baseData['admissionNo'] as String? ?? '',
            'studentName': baseData['fullName'] as String? ?? baseData['name'] as String? ?? '',
          });
        }
      } catch (_) {
        // If base student not found, still add with minimal data
        students.add({
          'studentId': studentId,
          'admissionNo': '',
          'studentName': '',
        });
      }
    }
    
    return students;
  }

  /// Get subjects from timetable for this exam & class-section
  Future<List<String>> _getSubjectsForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
  }) async {
    final docId = '${classId.trim()}-${sectionId.trim()}';
    final doc = await _examTimetableCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .doc(docId)
        .get();

    if (!doc.exists) {
      return const [];
    }

    final data = doc.data();
    if (data == null) return const [];

    final schedule = data['schedule'];
    if (schedule is! List) return const [];

    final subjects = <String>{};
    for (final item in schedule) {
      if (item is Map) {
        final schedule = ExamScheduleItem.fromMap(item.cast<String, Object?>());
        subjects.add(schedule.subject);
      }
    }

    return subjects.toList()..sort();
  }

  /// Generate CSV template for a class-section
  ///
  /// Downloads: studentId, admissionNo, studentName, subject1, subject2, ...
  Future<String> generateTemplateCsv({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
  }) async {
    final students = await _getStudentsForClassSection(
      schoolId: schoolId,
      yearId: yearId,
      classId: classId,
      sectionId: sectionId,
    );

    final subjects = await _getSubjectsForClassSection(
      schoolId: schoolId,
      yearId: yearId,
      examId: examId,
      classId: classId,
      sectionId: sectionId,
    );

    // Build headers: studentId, admissionNo, studentName, subject1, subject2, ...
    final headers = <String>['studentId', 'admissionNo', 'studentName'];
    headers.addAll(subjects);

    // Build rows
    final rows = <List<dynamic>>[headers];
    for (final student in students) {
      final row = <dynamic>[
        student['studentId'] ?? '',
        student['admissionNo'] ?? '',
        student['studentName'] ?? '',
      ];
      // Add empty cells for subjects
      for (int i = 0; i < subjects.length; i++) {
        row.add('');
      }
      rows.add(row);
    }

    // Convert to CSV
    return const ListToCsvConverter().convert(rows);
  }

  /// Parse and import CSV results
  ///
  /// CSV format: studentId, admissionNo, studentName, subject1, subject2, ...
  /// Rows: STU001, 1234, "Ayaan", 45, 40, 49, ...
  Future<ExamResultsCsvImportSummary> importResultsCsv({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required String csvText,
    required String enteredByUid,
    void Function(int done, int total)? onProgress,
  }) async {
    final converter = CsvToListConverter(shouldParseNumbers: false, eol: '\n');
    final table = converter.convert(csvText);

    if (table.isEmpty) {
      return const ExamResultsCsvImportSummary(
        totalRows: 0,
        successCount: 0,
        failureCount: 0,
        results: [],
      );
    }

    // Parse headers
    final headerRow = table.first;
    final headers = headerRow.map((x) => x.toString().trim().toLowerCase()).toList();

    // Validate required columns
    if (!headers.contains('studentid') ||
        !headers.contains('admissionno') ||
        !headers.contains('studentname')) {
      return ExamResultsCsvImportSummary(
        totalRows: table.length - 1,
        successCount: 0,
        failureCount: table.length - 1,
        results: [
          ExamResultsCsvRowResult(
            rowNumber: 1,
            studentId: '',
            success: false,
            message: 'Missing required columns: studentId, admissionNo, studentName',
          ),
        ],
      );
    }

    // Find subject column indices
    final subjectIndices = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      if (!['studentid', 'admissionno', 'studentname'].contains(headers[i])) {
        subjectIndices[headers[i]] = i;
      }
    }

    // Load existing results
    final existingSnap = await _examResultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .where('class', isEqualTo: classId.trim())
        .where('section', isEqualTo: sectionId.trim())
        .get();

    final existingByStudent = <String, Map<String, dynamic>>{};
    for (final doc in existingSnap.docs) {
      existingByStudent[doc.id] = doc.data();
    }

    // Load all year-students for validation
    final students = await _getStudentsForClassSection(
      schoolId: schoolId,
      yearId: yearId,
      classId: classId,
      sectionId: sectionId,
    );

    final studentIdSet = <String>{};
    for (final s in students) {
      studentIdSet.add(s['studentId'] as String);
    }

    // Process rows
    final results = <ExamResultsCsvRowResult>[];
    final writes = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, Object?>>>[];

    for (int rowIdx = 1; rowIdx < table.length; rowIdx++) {
      onProgress?.call(rowIdx, table.length - 1);

      final row = table[rowIdx];
      if (row.isEmpty) continue;

      try {
        // Extract base fields
        final studentId = _cellValue(row, headers.indexOf('studentid')).trim();
        final admissionNo = _cellValue(row, headers.indexOf('admissionno')).trim();
        final studentName = _cellValue(row, headers.indexOf('studentname')).trim();

        if (studentId.isEmpty) {
          results.add(ExamResultsCsvRowResult(
            rowNumber: rowIdx + 1,
            studentId: '',
            success: false,
            message: 'Student ID is required',
          ));
          continue;
        }

        // Validate student exists
        if (!studentIdSet.contains(studentId)) {
          results.add(ExamResultsCsvRowResult(
            rowNumber: rowIdx + 1,
            studentId: studentId,
            success: false,
            message: 'Student not found in this class-section',
          ));
          continue;
        }

        // Parse marks
        final subjects = <ExamSubjectResult>[];
        double totalObtained = 0;
        double totalMax = 0;

        // Load existing subjects if updating
        final existingData = existingByStudent[studentId];
        final existingSubjects = <ExamSubjectResult>[];
        if (existingData != null && existingData['subjects'] is List) {
          for (final s in existingData['subjects'] as List) {
            if (s is Map) {
              existingSubjects.add(ExamSubjectResult.fromMap(s.cast<String, Object?>()));
            }
          }
        }

        // Process each subject
        for (final subjectEntry in subjectIndices.entries) {
          final subject = subjectEntry.key;
          final idx = subjectEntry.value;

          final markStr = idx < row.length ? row[idx].toString().trim() : '';
          double obtained = 0;

          if (markStr.isNotEmpty) {
            try {
              obtained = double.parse(markStr);
              if (obtained < 0) {
                results.add(ExamResultsCsvRowResult(
                  rowNumber: rowIdx + 1,
                  studentId: studentId,
                  success: false,
                  message: 'Negative marks not allowed for $subject',
                ));
                break;
              }
            } catch (_) {
              results.add(ExamResultsCsvRowResult(
                rowNumber: rowIdx + 1,
                studentId: studentId,
                success: false,
                message: 'Invalid marks for $subject: "$markStr"',
              ));
              break;
            }
          }

          // Get max marks from existing or assume 100
          double maxMarks = 100;
          final existingSubject =
              existingSubjects.firstWhere((s) => s.subject.toLowerCase() == subject.toLowerCase(),
                  orElse: () => ExamSubjectResult(subject: subject, maxMarks: 100, obtainedMarks: 0));
          maxMarks = existingSubject.maxMarks;

          subjects.add(ExamSubjectResult(
            subject: subject,
            maxMarks: maxMarks,
            obtainedMarks: obtained,
          ));

          totalObtained += obtained;
          totalMax += maxMarks;
        }

        // Skip if there was a validation error
        if (subjects.isEmpty) continue;

        final percentage = totalMax <= 0 ? 0.0 : (totalObtained / totalMax) * 100.0;
        final grade = _gradeFromPercentage(percentage);

        // Check if previously published
        final wasPublished = existingData != null && (existingData['isPublished'] as bool?) == true;

        final resultRef = _examResultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
            .doc(studentId);
        writes.add(MapEntry(resultRef, {
          'studentId': studentId,
          'admissionNo': admissionNo,
          'studentName': studentName,
          'class': classId.trim(),
          'section': sectionId.trim(),
          'subjects': subjects.map((s) => s.toMap()).toList(),
          'total': double.parse(totalObtained.toStringAsFixed(2)),
          'percentage': double.parse(percentage.toStringAsFixed(2)),
          'grade': grade,
          'isPublished': wasPublished,
          'enteredByTeacherUid': enteredByUid,
          'updatedAt': FieldValue.serverTimestamp(),
        }));

        results.add(ExamResultsCsvRowResult(
          rowNumber: rowIdx + 1,
          studentId: studentId,
          success: true,
          message: 'OK',
        ));
      } catch (e) {
        results.add(ExamResultsCsvRowResult(
          rowNumber: rowIdx + 1,
          studentId: _cellValue(row, headers.indexOf('studentid')).trim(),
          success: false,
          message: 'Error: $e',
        ));
      }
    }

    // Commit writes in batches
    await _commitInChunks(writes);

    final successCount = results.where((r) => r.success).length;
    final failureCount = results.where((r) => !r.success).length;

    return ExamResultsCsvImportSummary(
      totalRows: table.length - 1,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
    );
  }

  /// Export existing results to CSV
  Future<String> exportResultsCsv({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
  }) async {
    final snap = await _examResultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .where('class', isEqualTo: classId.trim())
        .where('section', isEqualTo: sectionId.trim())
        .get();

    if (snap.docs.isEmpty) {
      return const ListToCsvConverter().convert([
        ['studentId', 'admissionNo', 'studentName', 'total', 'percentage', 'grade']
      ]);
    }

    // Collect all subjects
    final allSubjects = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['subjects'] is List) {
        for (final s in data['subjects'] as List) {
          if (s is Map) {
            allSubjects.add((s['subject'] ?? '').toString());
          }
        }
      }
    }
    final subjects = allSubjects.toList()..sort();

    // Build headers
    final headers = <String>['studentId', 'admissionNo', 'studentName'];
    headers.addAll(subjects);
    headers.addAll(['total', 'percentage', 'grade']);

    // Build rows
    final rows = <List<dynamic>>[headers];
    for (final doc in snap.docs) {
      final data = doc.data();
      final row = <dynamic>[
        data['studentId'] ?? '',
        data['admissionNo'] ?? '',
        data['studentName'] ?? '',
      ];

      // Map subjects by name
      final subjectMarkMap = <String, double>{};
      if (data['subjects'] is List) {
        for (final s in data['subjects'] as List) {
          if (s is Map) {
            subjectMarkMap[(s['subject'] ?? '').toString()] = (s['obtainedMarks'] ?? 0) as double;
          }
        }
      }

      // Add subject marks
      for (final subject in subjects) {
        row.add(subjectMarkMap[subject] ?? '');
      }

      // Add totals
      row.add(data['total'] ?? '');
      row.add(data['percentage'] ?? '');
      row.add(data['grade'] ?? '');

      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }

  // ===================== Helpers =====================

  String _cellValue(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return (row[idx] ?? '').toString().trim();
  }

  String _gradeFromPercentage(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  Future<void> _commitInChunks(
    List<MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, Object?>>> writes,
  ) async {
    const chunkSize = 400;
    for (int i = 0; i < writes.length; i += chunkSize) {
      final end = (i + chunkSize) > writes.length ? writes.length : (i + chunkSize);
      final batch = _firestore.batch();
      for (final w in writes.sublist(i, end)) {
        batch.set(w.key, w.value, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }
}
