import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/attendance_pa_entry.dart';
import '../models/student_base.dart';

/// Firestore-only attendance module (Firebase FREE plan friendly).
///
/// Attendance is stored under:
/// schools/{schoolId}/academicYears/{yearId}/attendance/{classId}/sections/{sectionId}/days/{yyyy-MM-dd}
///
/// Each day document contains:
/// - date (yyyy-MM-dd)
/// - class (classId)
/// - section (sectionId)
/// - markedByTeacherUid
/// - createdAt
/// - records: { studentId: "P" | "A" }
class AttendanceService {
  AttendanceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({
    String schoolId = AppConfig.schoolId,
  }) {
    return _firestore.collection('schools').doc(schoolId);
  }

  /// Date document id format required by spec: yyyy-MM-dd
  String dateId(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  DocumentReference<Map<String, dynamic>> attendanceDayDoc({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String classId,
    required String sectionId,
    required DateTime date,
  }) {
    return _schoolDoc(schoolId: schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('attendance')
        .doc(classId)
        .collection('sections')
        .doc(sectionId)
        .collection('days')
        .doc(dateId(date));
  }

  // ---------------------------------------------------------------------------
  // Attendance v3 (privacy-safe)
  // ---------------------------------------------------------------------------
  // Per-student attendance day docs:
  //   schools/{schoolId}/academicYears/{yearId}/attendanceStudents/{studentId}/days/{yyyy-MM-dd}
  // Optional per-classSection daily summaries:
  //   schools/{schoolId}/academicYears/{yearId}/attendanceSummaries/{classSectionId}/days/{yyyy-MM-dd}

  String classSectionId({required String classId, required String sectionId}) {
    return '${classId}_$sectionId';
  }

  DocumentReference<Map<String, dynamic>> attendanceStudentDayDoc({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String studentId,
    required DateTime date,
  }) {
    return _schoolDoc(schoolId: schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('attendanceStudents')
        .doc(studentId)
        .collection('days')
        .doc(dateId(date));
  }

  DocumentReference<Map<String, dynamic>> attendanceSummaryDayDoc({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String classSectionId,
    required DateTime date,
  }) {
    return _schoolDoc(schoolId: schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('attendanceSummaries')
        .doc(classSectionId)
        .collection('days')
        .doc(dateId(date));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchAttendanceSummaryDay({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String classId,
    required String sectionId,
    required DateTime date,
  }) {
    return attendanceSummaryDayDoc(
      schoolId: schoolId,
      yearId: yearId,
      classSectionId: classSectionId(classId: classId, sectionId: sectionId),
      date: date,
    ).snapshots();
  }

  /// Watches v3 per-student attendance docs for a month.
  ///
  /// Returns only this student's entries (no privacy leak).
  Stream<List<AttendancePAEntry>> watchStudentAttendanceV3ForMonth({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String studentId,
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final startId = dateId(start);
    final endId = dateId(end);

    final daysCol = _schoolDoc(schoolId: schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('attendanceStudents')
        .doc(studentId)
        .collection('days');

    final q = daysCol
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startId)
        .where(FieldPath.documentId, isLessThan: endId);

    return q.snapshots().map((snap) {
      final list = <AttendancePAEntry>[];
      for (final d in snap.docs) {
        final data = d.data();
        final status = (data['status'] as String?);
        final safeStatus = (status == 'P' || status == 'A') ? status : null;

        final parts = d.id.split('-');
        DateTime parsed;
        if (parts.length == 3) {
          parsed = DateTime(
            int.tryParse(parts[0]) ?? start.year,
            int.tryParse(parts[1]) ?? start.month,
            int.tryParse(parts[2]) ?? 1,
          );
        } else {
          parsed = start;
        }

        list.add(
          AttendancePAEntry(dateId: d.id, date: parsed, status: safeStatus),
        );
      }

      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  /// Saves v3 attendance for a class/section by writing one per-student day doc.
  ///
  /// NOTE: This is not strictly atomic for very large classes (batches are chunked).
  Future<void> saveAttendanceDayV3({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String classId,
    required String sectionId,
    required DateTime date,
    required String markedByUid,
    required List<StudentBase> students,
    required Map<String, String> records,
    required bool overwriteIfExists,
  }) async {
    // Validate map values early.
    for (final v in records.values) {
      if (v != 'P' && v != 'A') {
        throw Exception('Invalid attendance value: $v');
      }
    }

    final normalized = DateTime(date.year, date.month, date.day);
    final csId = classSectionId(classId: classId, sectionId: sectionId);
    final summaryRef = attendanceSummaryDayDoc(
      schoolId: schoolId,
      yearId: yearId,
      classSectionId: csId,
      date: normalized,
    );

    final existingSummary = await summaryRef.get();
    if (existingSummary.exists && !overwriteIfExists) {
      throw AttendanceAlreadyMarkedException(
        'Attendance already marked for this day',
      );
    }

    var presentCount = 0;
    var absentCount = 0;
    for (final s in students) {
      final v = records[s.id];
      if (v == 'P') presentCount++;
      if (v == 'A') absentCount++;
    }

    final summaryPayload = <String, Object?>{
      'dateId': dateId(normalized),
      'date': Timestamp.fromDate(normalized),
      'class': classId,
      'section': sectionId,
      'classSectionId': csId,
      'totalStudents': students.length,
      'presentCount': presentCount,
      'absentCount': absentCount,
      // New canonical field names
      'markedByUid': markedByUid,
      'markedAt': FieldValue.serverTimestamp(),
      // Legacy/compat field name (keep so older UIs/rules don't break)
      'markedByTeacherUid': markedByUid,
      'createdAt': existingSummary.exists
          ? (existingSummary.data()?['createdAt'] ??
                FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Write per-student docs in chunks to stay within batch limits.
    const maxBatchWrites = 450;
    var i = 0;
    while (i < students.length) {
      final end = (i + maxBatchWrites) > students.length
          ? students.length
          : (i + maxBatchWrites);
      final batch = _firestore.batch();

      for (final s in students.sublist(i, end)) {
        final status = records[s.id] ?? 'P';
        final dayRef = attendanceStudentDayDoc(
          schoolId: schoolId,
          yearId: yearId,
          studentId: s.id,
          date: normalized,
        );

        final payload = <String, Object?>{
          // Required by spec
          'studentId': s.id,
          'class': classId,
          'section': sectionId,
          'groupId': s.groupId,
          'date': Timestamp.fromDate(normalized),
          'status': status,
          'markedByUid': markedByUid,
          'markedAt': FieldValue.serverTimestamp(),
          // Convenience / legacy
          'dateId': dateId(normalized),
          'classSectionId': csId,
          'markedByTeacherUid': markedByUid,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(dayRef, payload, SetOptions(merge: true));
      }

      // Write the summary doc on the last chunk so the UI's "already marked" check
      // has a single canonical indicator.
      if (end == students.length) {
        batch.set(summaryRef, summaryPayload, SetOptions(merge: true));
      }

      await batch.commit();
      i = end;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchAttendanceDay({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String classId,
    required String sectionId,
    required DateTime date,
  }) {
    return attendanceDayDoc(
      schoolId: schoolId,
      yearId: yearId,
      classId: classId,
      sectionId: sectionId,
      date: date,
    ).snapshots();
  }

  /// Watches base students for a class/section.
  ///
  /// This is designed to load ~700 students efficiently with a single query.
  Stream<List<StudentBase>> watchStudentsForClassSection({
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String sectionId,
  }) {
    final q = _schoolDoc(schoolId: schoolId)
        .collection('students')
        .where('class', isEqualTo: classId)
        .where('section', isEqualTo: sectionId)
        .orderBy('name');

    return q.snapshots().map((snap) {
      return snap.docs
          .map((d) => StudentBase.fromMap(d.id, d.data()))
          .toList(growable: false);
    });
  }

  /// Watches all attendance day docs for a class/section within a month,
  /// but returns entries for a *single student* by extracting
  /// `records[studentId]` from each day document.
  ///
  /// This avoids any per-student writes and keeps parent view reads bounded
  /// to the month (typically ~20-31 documents).
  Stream<List<AttendancePAEntry>> watchStudentAttendanceForMonth({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String classId,
    required String sectionId,
    required String studentId,
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final startId = dateId(start);
    final endId = dateId(end);

    final daysCol = _schoolDoc(schoolId: schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('attendance')
        .doc(classId)
        .collection('sections')
        .doc(sectionId)
        .collection('days');

    final q = daysCol
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startId)
        .where(FieldPath.documentId, isLessThan: endId);

    return q.snapshots().map((snap) {
      final list = <AttendancePAEntry>[];
      for (final d in snap.docs) {
        final data = d.data();
        final rawRecords = data['records'];
        String? status;
        if (rawRecords is Map) {
          final v = rawRecords[studentId];
          final s = v?.toString();
          if (s == 'P' || s == 'A') status = s;
        }

        final parts = d.id.split('-');
        DateTime parsed;
        if (parts.length == 3) {
          parsed = DateTime(
            int.tryParse(parts[0]) ?? start.year,
            int.tryParse(parts[1]) ?? start.month,
            int.tryParse(parts[2]) ?? 1,
          );
        } else {
          parsed = start;
        }

        list.add(AttendancePAEntry(dateId: d.id, date: parsed, status: status));
      }

      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  Future<void> saveAttendanceDay({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String classId,
    required String sectionId,
    required DateTime date,
    required String markedByTeacherUid,
    required Map<String, String> records,
    required bool overwriteIfExists,
  }) async {
    // Validate map values early.
    for (final v in records.values) {
      if (v != 'P' && v != 'A') {
        throw Exception('Invalid attendance value: $v');
      }
    }

    final normalized = DateTime(date.year, date.month, date.day);
    final dayRef = attendanceDayDoc(
      schoolId: schoolId,
      yearId: yearId,
      classId: classId,
      sectionId: sectionId,
      date: normalized,
    );

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(dayRef);
      if (snap.exists && !overwriteIfExists) {
        throw AttendanceAlreadyMarkedException(
          'Attendance already marked for this day',
        );
      }

      final payload = <String, Object?>{
        'date': dateId(normalized),
        'class': classId,
        'section': sectionId,
        'markedByTeacherUid': markedByTeacherUid,
        'createdAt': snap.exists
            ? (snap.data()?['createdAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'records': records,
        // Not required by spec, but useful for audits when overwriting.
        'updatedAt': FieldValue.serverTimestamp(),
      };

      tx.set(dayRef, payload, SetOptions(merge: false));
    });
  }
}

class AttendanceAlreadyMarkedException implements Exception {
  AttendanceAlreadyMarkedException(this.message);
  final String message;

  @override
  String toString() => message;
}
