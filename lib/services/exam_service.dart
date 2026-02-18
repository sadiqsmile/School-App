import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/exam.dart';
import '../models/exam_result.dart';
import '../models/exam_schedule_item.dart';
import '../models/exam_subject_result.dart';
import '../models/exam_timetable.dart';
import '../models/year_student.dart';

/// Exams Module v1 (Firestore-only, no Cloud Functions)
///
/// Must follow (per academic year):
/// schools/{schoolId}/academicYears/{yearId}/exams/{examId}
///   - examName (string)
///   - groupId (string: primary/middle/highschool)
///   - startDate (timestamp)
///   - endDate (timestamp)
///   - isActive (bool)
///   - createdAt (timestamp)
///
/// Timetable (one doc per class-section):
/// schools/{schoolId}/academicYears/{yearId}/exams/{examId}/timetable/{classSectionId}
///   - class (string)
///   - section (string)
///   - schedule (array<{date, subject, startTime, endTime}>)
///   - isPublished (bool)
///   - updatedAt (timestamp)
///
/// Results (one doc per student):
/// schools/{schoolId}/academicYears/{yearId}/exams/{examId}/results/{studentId}
///   - studentId, admissionNo, studentName, class, section, groupId
///   - subjects (array<{subject, maxMarks, obtainedMarks}>)
///   - total, percentage, grade
///   - isPublished (bool)
///   - updatedAt
///   - enteredByTeacherUid
class ExamService {
  ExamService({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> examsCol({
    String schoolId = AppConfig.schoolId,
    required String yearId,
  }) {
    return _yearDoc(schoolId: schoolId, yearId: yearId).collection('exams');
  }

  Stream<List<Exam>> watchExams({
    String schoolId = AppConfig.schoolId,
    required String yearId,
  }) {
    return examsCol(schoolId: schoolId, yearId: yearId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Exam.fromDoc).toList(growable: false));
  }

  Stream<List<Exam>> watchExamsForGroup({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String groupId,
    bool onlyActive = true,
  }) {
    Query<Map<String, dynamic>> q = examsCol(schoolId: schoolId, yearId: yearId)
        .where('groupId', isEqualTo: groupId.trim());
    if (onlyActive) q = q.where('isActive', isEqualTo: true);
    q = q.orderBy('startDate', descending: false);
    return q.snapshots().map((snap) => snap.docs.map(Exam.fromDoc).toList(growable: false));
  }

  Stream<List<Exam>> watchExamsForGroups({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required List<String> groupIds,
    bool onlyActive = true,
  }) {
    final cleaned = groupIds.map((g) => g.trim()).where((g) => g.isNotEmpty).toSet().toList()..sort();
    if (cleaned.isEmpty) return const Stream<List<Exam>>.empty();

    if (cleaned.length == 1) {
      return watchExamsForGroup(
        schoolId: schoolId,
        yearId: yearId,
        groupId: cleaned.first,
        onlyActive: onlyActive,
      );
    }

    Query<Map<String, dynamic>> q = examsCol(schoolId: schoolId, yearId: yearId)
        .where('groupId', whereIn: cleaned);
    if (onlyActive) q = q.where('isActive', isEqualTo: true);
    q = q.orderBy('startDate', descending: false);
    return q.snapshots().map((snap) => snap.docs.map(Exam.fromDoc).toList(growable: false));
  }

  Stream<Exam?> watchExam({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
  }) {
    return examsCol(schoolId: schoolId, yearId: yearId)
        .doc(examId)
        .snapshots()
        .map((d) => d.exists ? Exam.fromDoc(d) : null);
  }

  Future<String> createExam({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examName,
    required String groupId,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    final cleanedName = examName.trim();
    final cleanedGroup = groupId.trim();
    if (cleanedName.isEmpty) throw Exception('Exam name is required');
    if (cleanedGroup.isEmpty) throw Exception('Group is required');

    final ref = examsCol(schoolId: schoolId, yearId: yearId).doc();
    await ref.set({
      'examName': cleanedName,
      'groupId': cleanedGroup,
      'startDate': startDate == null ? null : Timestamp.fromDate(_dateOnly(startDate)),
      'endDate': endDate == null ? null : Timestamp.fromDate(_dateOnly(endDate)),
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateExam({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String examName,
    required String groupId,
    DateTime? startDate,
    DateTime? endDate,
    required bool isActive,
  }) {
    final cleanedName = examName.trim();
    final cleanedGroup = groupId.trim();
    if (cleanedName.isEmpty) throw Exception('Exam name is required');
    if (cleanedGroup.isEmpty) throw Exception('Group is required');

    return examsCol(schoolId: schoolId, yearId: yearId).doc(examId).set({
      'examName': cleanedName,
      'groupId': cleanedGroup,
      'startDate': startDate == null ? null : Timestamp.fromDate(_dateOnly(startDate)),
      'endDate': endDate == null ? null : Timestamp.fromDate(_dateOnly(endDate)),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------- Timetable ----------------

  CollectionReference<Map<String, dynamic>> timetableCol({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
  }) {
    return examsCol(schoolId: schoolId, yearId: yearId).doc(examId).collection('timetable');
  }

  Stream<List<ExamTimetable>> watchTimetable({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
  }) {
    return timetableCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .snapshots()
        .map((snap) => snap.docs.map(ExamTimetable.fromDoc).toList(growable: false));
  }

  Stream<ExamTimetable?> watchTimetableForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
  }) {
    final docId = classSectionDocId(classId: classId, sectionId: sectionId);
    return timetableCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .doc(docId)
        .snapshots()
        .map((d) => d.exists ? ExamTimetable.fromDoc(d) : null);
  }

  Future<void> upsertTimetableForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required List<ExamScheduleItem> schedule,
  }) async {
    final cleanedClass = classId.trim();
    final cleanedSection = sectionId.trim();
    if (cleanedClass.isEmpty) throw Exception('Class is required');
    if (cleanedSection.isEmpty) throw Exception('Section is required');

    final docId = classSectionDocId(classId: cleanedClass, sectionId: cleanedSection);
    final ref = timetableCol(schoolId: schoolId, yearId: yearId, examId: examId).doc(docId);

    await ref.set({
      'class': cleanedClass,
      'section': cleanedSection,
      'schedule': schedule.map((s) => s.toMap()).toList(),
      // Don't change publish status here (admin can toggle separately)
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setTimetablePublished({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required bool isPublished,
  }) {
    final docId = classSectionDocId(classId: classId, sectionId: sectionId);
    return timetableCol(schoolId: schoolId, yearId: yearId, examId: examId).doc(docId).set({
      'isPublished': isPublished,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------- Marks ----------------

  CollectionReference<Map<String, dynamic>> resultsCol({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
  }) {
    return examsCol(schoolId: schoolId, yearId: yearId).doc(examId).collection('results');
  }

  Stream<List<ExamResult>> watchResultsForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
  }) {
    return resultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .where('class', isEqualTo: classId.trim())
        .where('section', isEqualTo: sectionId.trim())
        .snapshots()
        .map((snap) => snap.docs.map(ExamResult.fromDoc).toList(growable: false));
  }

  Stream<ExamResult?> watchResultForStudent({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String studentId,
  }) {
    return resultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .doc(studentId.trim())
        .snapshots()
        .map((d) => d.exists ? ExamResult.fromDoc(d) : null);
  }

  Future<void> upsertSubjectMarksForStudents({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String groupId,
    required String classId,
    required String sectionId,
    required String subject,
    required double maxMarks,
    required String enteredByTeacherUid,
    required List<YearStudent> students,
    required Map<String, double?> obtainedByStudentId,
  }) async {
    final cleanedGroup = groupId.trim();
    final cleanedClass = classId.trim();
    final cleanedSection = sectionId.trim();
    final cleanedSubject = subject.trim();
    if (cleanedGroup.isEmpty) throw Exception('Group is required');
    if (cleanedClass.isEmpty) throw Exception('Class is required');
    if (cleanedSection.isEmpty) throw Exception('Section is required');
    if (cleanedSubject.isEmpty) throw Exception('Subject is required');
    if (maxMarks <= 0) throw Exception('Max marks must be > 0');

    // Load existing results for this class-section to support editing.
    final existingSnap = await resultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .where('class', isEqualTo: cleanedClass)
        .where('section', isEqualTo: cleanedSection)
        .get();

    final existingByStudent = <String, Map<String, dynamic>>{};
    for (final d in existingSnap.docs) {
      existingByStudent[d.id] = d.data();
    }

    final writes = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, Object?>>>[];

    for (final s in students) {
      final studentId = s.base.id;
      final obtained = obtainedByStudentId[studentId];
      if (obtained == null) continue;
      if (obtained < 0) throw Exception('Marks cannot be negative');
      if (obtained > maxMarks) throw Exception('Marks cannot exceed max marks');

      final existing = existingByStudent[studentId];
      
      // Preserve approval/publish status on updates
      final wasApproved = (existing == null ? null : existing['isApproved']) ?? false;
      final wasPublished = (existing == null ? null : existing['isPublished']) ?? false;

      // Merge subjects.
      final rawSubjects = existing == null ? null : existing['subjects'];
      final subjects = <ExamSubjectResult>[];
      if (rawSubjects is List) {
        for (final it in rawSubjects) {
          if (it is Map) subjects.add(ExamSubjectResult.fromMap(it.cast<String, Object?>()));
        }
      }

      final idx = subjects.indexWhere((x) => x.subject.toLowerCase() == cleanedSubject.toLowerCase());
      final next = ExamSubjectResult(subject: cleanedSubject, maxMarks: maxMarks, obtainedMarks: obtained);
      if (idx >= 0) {
        subjects[idx] = next;
      } else {
        subjects.add(next);
      }

      // Totals.
      final totalObtained = subjects.fold<double>(0, (acc, x) => acc + x.obtainedMarks);
      final totalMax = subjects.fold<double>(0, (acc, x) => acc + x.maxMarks);
      final percentage = totalMax <= 0 ? 0.0 : (totalObtained / totalMax) * 100.0;
      final grade = gradeFromPercentage(percentage);

      final ref = resultsCol(schoolId: schoolId, yearId: yearId, examId: examId).doc(studentId);
      writes.add(MapEntry(ref, {
        'studentId': studentId,
        'admissionNo': s.base.admissionNo,
        'studentName': s.base.fullName,
        'class': cleanedClass,
        'section': cleanedSection,
        'groupId': cleanedGroup,
        'subjects': subjects.map((e) => e.toMap()).toList(),
        'total': totalObtained,
        'percentage': double.parse(percentage.toStringAsFixed(2)),
        'grade': grade,
        'enteredByUid': enteredByTeacherUid,
        'enteredAt': FieldValue.serverTimestamp(),
        'isApproved': wasApproved, // Preserve approval status
        'isPublished': wasPublished, // Preserve publish status
        'enteredByTeacherUid': enteredByTeacherUid, // Kept for backward compat
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }

    await _commitInChunks(writes);
  }

  // ===================== Approval Workflow (v2) =====================

  /// Admin approves results for a student (before publishing)
  Future<void> approveResultForStudent({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String studentId,
    required String approvedByUid,
  }) {
    return resultsCol(schoolId: schoolId, yearId: yearId, examId: examId).doc(studentId).set({
      'isApproved': true,
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Admin approves all results for a class-section (before publishing)
  Future<void> approveResultsForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required String approvedByUid,
  }) async {
    final cleanedClass = classId.trim();
    final cleanedSection = sectionId.trim();

    final snap = await resultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .where('class', isEqualTo: cleanedClass)
        .where('section', isEqualTo: cleanedSection)
        .get();

    final writes = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, Object?>>>[];
    for (final d in snap.docs) {
      writes.add(MapEntry(d.reference, {
        'isApproved': true,
        'approvedByUid': approvedByUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }
    await _commitInChunks(writes);
  }

  /// Get approval status for a class-section
  Stream<List<ExamResult>> watchResultsApprovalStatusForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
  }) {
    return resultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .where('class', isEqualTo: classId.trim())
        .where('section', isEqualTo: sectionId.trim())
        .snapshots()
        .map((snap) => snap.docs.map(ExamResult.fromDoc).toList(growable: false));
  }

  /// Admin publishes approved results for class-section
  /// Throws if any result is not approved
  Future<void> publishResultsForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required String publishedByUid,
  }) async {
    final cleanedClass = classId.trim();
    final cleanedSection = sectionId.trim();

    final snap = await resultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .where('class', isEqualTo: cleanedClass)
        .where('section', isEqualTo: cleanedSection)
        .get();

    // Check all are approved
    for (final d in snap.docs) {
      if ((d['isApproved'] ?? false) != true) {
        throw Exception('Cannot publish: not all results are approved');
      }
    }

    // All approved, proceed with publish
    final writes = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, Object?>>>[];
    for (final d in snap.docs) {
      writes.add(MapEntry(d.reference, {
        'isPublished': true,
        'publishedByUid': publishedByUid,
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }
    await _commitInChunks(writes);
  }

  /// Set publish status for a single class-section.
  ///
  /// - When publishing (isPublished=true), we enforce the same rule as
  ///   [publishResultsForClassSection]: every result must be approved.
  /// - When unpublishing (isPublished=false), we simply set isPublished=false.
  Future<void> setResultsPublishedForClassSection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required bool isPublished,
    String? publishedByUid,
  }) async {
    final cleanedClass = classId.trim();
    final cleanedSection = sectionId.trim();
    if (cleanedClass.isEmpty) throw Exception('Class is required');
    if (cleanedSection.isEmpty) throw Exception('Section is required');

    final snap = await resultsCol(schoolId: schoolId, yearId: yearId, examId: examId)
        .where('class', isEqualTo: cleanedClass)
        .where('section', isEqualTo: cleanedSection)
        .get();

    if (isPublished) {
      // Enforce approval before publishing.
      for (final d in snap.docs) {
        if ((d['isApproved'] ?? false) != true) {
          throw Exception('Cannot publish: not all results are approved');
        }
      }
    }

    final writes = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, Object?>>>[];
    for (final d in snap.docs) {
      final payload = <String, Object?>{
        'isPublished': isPublished,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isPublished) {
        payload['publishedByUid'] = (publishedByUid ?? '').trim().isEmpty ? null : publishedByUid;
        payload['publishedAt'] = FieldValue.serverTimestamp();
      } else {
        payload['publishedByUid'] = FieldValue.delete();
        payload['publishedAt'] = FieldValue.delete();
      }
      writes.add(MapEntry(d.reference, payload));
    }

    await _commitInChunks(writes);
  }

  /// Exam-wide publish toggle.
  ///
  /// NOTE: This may involve many writes. We chunk writes, but on a large school
  /// you may still hit quota/time. Consider using class-wise publish first.
  Future<void> setResultsPublishedForExam({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String examId,
    required bool isPublished,
  }) async {
    final snap = await resultsCol(schoolId: schoolId, yearId: yearId, examId: examId).get();
    final writes = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, Object?>>>[];
    for (final d in snap.docs) {
      writes.add(MapEntry(d.reference, {
        'isPublished': isPublished,
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }
    await _commitInChunks(writes);
  }

  // ---------------- Helpers ----------------

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String classSectionDocId({required String classId, required String sectionId}) {
    // Required example: "5-A"
    return '${classId.trim()}-${sectionId.trim()}';
  }

  static String gradeFromPercentage(double p) {
    final v = p.isNaN ? 0.0 : p;
    if (v >= 90) return 'A+';
    if (v >= 80) return 'A';
    if (v >= 70) return 'B+';
    if (v >= 60) return 'B';
    if (v >= 50) return 'C';
    if (v >= 40) return 'D';
    return 'F';
  }

  Future<void> _commitInChunks(
    List<MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, Object?>>> writes,
  ) async {
    const chunkSize = 400; // keep a safety buffer under 500
    for (var i = 0; i < writes.length; i += chunkSize) {
      final end = (i + chunkSize) > writes.length ? writes.length : (i + chunkSize);
      final batch = _firestore.batch();
      for (final w in writes.sublist(i, end)) {
        batch.set(w.key, w.value, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }
}
