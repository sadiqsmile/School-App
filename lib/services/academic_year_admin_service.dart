import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class RolloverPreviewIssue {
  const RolloverPreviewIssue({
    required this.studentId,
    required this.message,
  });

  final String studentId;
  final String message;
}

class RolloverPreview {
  const RolloverPreview({
    required this.totalStudents,
    required this.consideredStudents,
    required this.promoteCount,
    required this.alumniCount,
    required this.skippedCount,
    required this.issues,
  });

  final int totalStudents;
  final int consideredStudents;
  final int promoteCount;
  final int alumniCount;
  final int skippedCount;
  final List<RolloverPreviewIssue> issues;
}

class RolloverProgress {
  const RolloverProgress({
    required this.done,
    required this.total,
    required this.message,
  });

  final int done;
  final int total;
  final String message;
}

class AcademicYearAdminService {
  AcademicYearAdminService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  CollectionReference<Map<String, dynamic>> schoolAcademicYearsCol({String schoolId = AppConfig.schoolId}) {
    // Spec: schools/{schoolId}/academicYears/{yearId}
    return _schoolDoc(schoolId: schoolId).collection('academicYears');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSchoolAcademicYears({String schoolId = AppConfig.schoolId}) {
    return schoolAcademicYearsCol(schoolId: schoolId)
        .orderBy(FieldPath.documentId, descending: true)
        .snapshots();
  }

  Future<void> createAcademicYear({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    String? label,
  }) async {
    final y = yearId.trim();
    if (y.isEmpty) throw Exception('Year ID is required');

    // Create the per-school year document (used by modules).
    await schoolAcademicYearsCol(schoolId: schoolId).doc(y).set({
      'yearId': y,
      'label': (label ?? y).trim().isEmpty ? y : (label ?? y).trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also ensure a global academicYears/{yearId} doc exists for legacy year-specific helpers
    // (classSections, year-students). This keeps the existing app structure working.
    await _firestore.collection('academicYears').doc(y).set({
      'yearId': y,
      'label': (label ?? y).trim().isEmpty ? y : (label ?? y).trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setActiveAcademicYearId({
    String schoolId = AppConfig.schoolId,
    required String yearId,
  }) {
    final y = yearId.trim();
    if (y.isEmpty) throw Exception('Year ID is required');

    return _schoolDoc(schoolId: schoolId).collection('settings').doc('app').set({
      'activeAcademicYearId': y,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Copies year class-sections (used for teacher assignments UI) from one year to another.
  ///
  /// Path used by existing app code:
  /// academicYears/{yearId}/schools/{schoolId}/classSections/{classSectionId}
  Future<int> copyYearClassSections({
    required String fromYearId,
    required String toYearId,
    String schoolId = AppConfig.schoolId,
  }) async {
    final from = fromYearId.trim();
    final to = toYearId.trim();
    if (from.isEmpty || to.isEmpty) throw Exception('Year IDs are required');

    final fromCol = _firestore
        .collection('academicYears')
        .doc(from)
        .collection('schools')
        .doc(schoolId)
        .collection('classSections');

    final toCol = _firestore
        .collection('academicYears')
        .doc(to)
        .collection('schools')
        .doc(schoolId)
        .collection('classSections');

    final snap = await fromCol.get();
    if (snap.docs.isEmpty) return 0;

    var copied = 0;
    WriteBatch batch = _firestore.batch();
    var writes = 0;

    Future<void> flush() async {
      if (writes == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      writes = 0;
    }

    for (final d in snap.docs) {
      batch.set(
        toCol.doc(d.id),
        {
          ...d.data(),
          'copiedFromYearId': from,
          'updatedAt': FieldValue.serverTimestamp(),
          if (d.data()['createdAt'] == null) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      copied++;
      writes++;
      if (writes >= 450) await flush();
    }

    await flush();
    return copied;
  }

  Future<RolloverPreview> previewPromotion({
    String schoolId = AppConfig.schoolId,
    required int finalClassNumber,
    bool onlyActiveStudents = true,
  }) async {
    if (finalClassNumber < 1) throw Exception('Final class must be >= 1');

    Query<Map<String, dynamic>> q = _schoolDoc(schoolId: schoolId).collection('students');
    if (onlyActiveStudents) {
      q = q.where('isActive', isEqualTo: true);
    }

    final snap = await q.get();

    var promote = 0;
    var alumni = 0;
    var skipped = 0;
    final issues = <RolloverPreviewIssue>[];

    for (final d in snap.docs) {
      final data = d.data();
      final classRaw = ((data['class'] as String?) ?? (data['classId'] as String?) ?? '').trim();
      final sectionRaw = ((data['section'] as String?) ?? (data['sectionId'] as String?) ?? '').trim();

      final n = int.tryParse(classRaw);
      if (n == null) {
        skipped++;
        issues.add(RolloverPreviewIssue(studentId: d.id, message: 'Non-numeric class "$classRaw"'));
        continue;
      }
      if (sectionRaw.isEmpty) {
        skipped++;
        issues.add(RolloverPreviewIssue(studentId: d.id, message: 'Missing section'));
        continue;
      }

      if (n >= finalClassNumber) {
        alumni++;
      } else {
        promote++;
      }
    }

    return RolloverPreview(
      totalStudents: snap.size,
      consideredStudents: snap.size,
      promoteCount: promote,
      alumniCount: alumni,
      skippedCount: skipped,
      issues: issues,
    );
  }

  /// Rollover wizard action:
  /// - Ensures the `toYearId` exists (school + global)
  /// - Optionally copies classSections (global academicYears structure)
  /// - Promotes base students (class N -> N+1)
  /// - Marks final class as alumni/inactive
  /// - Creates/updates global year-student docs used by the existing app UI
  Future<void> rolloverAndPromoteStudents({
    String schoolId = AppConfig.schoolId,
    required String fromYearId,
    required String toYearId,
    required int finalClassNumber,
    bool onlyActiveStudents = true,
    bool copyClassSections = true,
    bool setActiveYearAfter = true,
    void Function(RolloverProgress p)? onProgress,
  }) async {
    final from = fromYearId.trim();
    final to = toYearId.trim();
    if (from.isEmpty || to.isEmpty) throw Exception('Year IDs are required');
    if (finalClassNumber < 1) throw Exception('Final class must be >= 1');

    onProgress?.call(const RolloverProgress(done: 0, total: 0, message: 'Ensuring academic year documents…'));
    await createAcademicYear(schoolId: schoolId, yearId: to, label: to);

    if (copyClassSections) {
      onProgress?.call(const RolloverProgress(done: 0, total: 0, message: 'Copying year class-sections…'));
      await copyYearClassSections(fromYearId: from, toYearId: to, schoolId: schoolId);
    }

    // Load students (paged) and apply promotions.
    Query<Map<String, dynamic>> baseQ = _schoolDoc(schoolId: schoolId).collection('students').orderBy(FieldPath.documentId);
    if (onlyActiveStudents) {
      baseQ = _schoolDoc(schoolId: schoolId)
          .collection('students')
          .where('isActive', isEqualTo: true)
          .orderBy(FieldPath.documentId);
    }

    // Total count is optional; to keep it free-plan friendly, we don't do an extra count query.
    int done = 0;

    DocumentSnapshot<Map<String, dynamic>>? last;

    while (true) {
      var q = baseQ.limit(200);
      if (last != null) q = q.startAfterDocument(last);

      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      // Each student uses ~2 writes (base student + year-student).
      // With limit(200) we stay within Firestore's 500 writes/batch limit.

      for (final d in snap.docs) {
        final data = d.data();
        final studentId = d.id;

        final classRaw = ((data['class'] as String?) ?? (data['classId'] as String?) ?? '').trim();
        final sectionRaw = ((data['section'] as String?) ?? (data['sectionId'] as String?) ?? '').trim();
        final groupRaw = ((data['group'] as String?) ?? (data['groupId'] as String?) ?? '').trim();
        final parentMobile = (data['parentMobile'] as String?)?.trim() ?? '';

        final n = int.tryParse(classRaw);
        if (n == null || sectionRaw.isEmpty) {
          // Skip non-standard / incomplete student rows. Admin can fix and retry.
          continue;
        }

        if (n >= finalClassNumber) {
          batch.set(
            d.reference,
            {
              'isActive': false,
              'status': 'alumni',
              'completedAt': FieldValue.serverTimestamp(),
              'completedYearId': from,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          // Still create year-student doc (optional, but keeps history discoverable).
          final yearStudentRef = _firestore
              .collection('academicYears')
              .doc(to)
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .doc(studentId);

          batch.set(
            yearStudentRef,
            {
              'studentId': studentId,
              'classSectionId': '${classRaw}_$sectionRaw',
              'parentUids': parentMobile.isEmpty ? [] : [parentMobile],
              'groupId': groupRaw,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } else {
          final nextClass = (n + 1).toString();

          batch.set(
            d.reference,
            {
              'class': nextClass,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          final yearStudentRef = _firestore
              .collection('academicYears')
              .doc(to)
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .doc(studentId);

          batch.set(
            yearStudentRef,
            {
              'studentId': studentId,
              'classSectionId': '${nextClass}_$sectionRaw',
              'parentUids': parentMobile.isEmpty ? [] : [parentMobile],
              'groupId': groupRaw,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();

      done += snap.docs.length;
      onProgress?.call(RolloverProgress(done: done, total: -1, message: 'Updated $done students…'));

      last = snap.docs.last;
    }

    if (setActiveYearAfter) {
      onProgress?.call(const RolloverProgress(done: 0, total: 0, message: 'Setting active academic year…'));
      await setActiveAcademicYearId(schoolId: schoolId, yearId: to);
    }

    onProgress?.call(const RolloverProgress(done: 0, total: 0, message: 'Done'));
  }
}
