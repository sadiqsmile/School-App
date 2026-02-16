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

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
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
        throw AttendanceAlreadyMarkedException('Attendance already marked for this day');
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
