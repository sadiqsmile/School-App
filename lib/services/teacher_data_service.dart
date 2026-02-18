import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/attendance_status.dart';
import '../models/student_base.dart';
import '../models/student_year.dart';
import '../models/year_student.dart';

class TeacherDataService {
  TeacherDataService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<String>> watchAssignedClassSectionIds({
    String schoolId = AppConfig.schoolId,
    required String teacherUid,
  }) {
    final doc = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teacherAssignments')
        .doc(teacherUid);

    return doc.snapshots().map((snap) {
      final data = snap.data();
      final ids = (data == null ? null : data['classSectionIds']) as List?;
      return (ids ?? const []).whereType<String>().toList();
    });
  }

  CollectionReference<Map<String, dynamic>> _yearStudents({
    required String yearId,
    required String schoolId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('students');
  }

  DocumentReference<Map<String, dynamic>> _studentBase({
    required String schoolId,
    required String studentId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId);
  }

  Stream<List<YearStudent>> watchStudentsForClassSection({
    required String yearId,
    String schoolId = AppConfig.schoolId,
    required String classSectionId,
  }) {
    final query = _yearStudents(yearId: yearId, schoolId: schoolId)
        .where('classSectionId', isEqualTo: classSectionId);

    return query.snapshots().asyncMap((snapshot) async {
      final items = <YearStudent>[];

      for (final doc in snapshot.docs) {
        final year = StudentYear.fromMap(doc.id, doc.data());
        final baseSnap =
            await _studentBase(schoolId: schoolId, studentId: year.studentId).get();
        final baseData = baseSnap.data() ?? const <String, Object?>{};
        final base = StudentBase.fromMap(year.studentId, baseData);
        items.add(YearStudent(base: base, year: year));
      }

      items.sort((a, b) {
        final ar = a.year.rollNo ?? 999999;
        final br = b.year.rollNo ?? 999999;
        if (ar != br) return ar.compareTo(br);
        return a.base.fullName.compareTo(b.base.fullName);
      });

      return items;
    });
  }

  Future<AttendanceStatus?> getAttendanceStatus({
    required String yearId,
    String schoolId = AppConfig.schoolId,
    required String studentId,
    required DateTime date,
  }) async {
    final docId = _dateDocId(date);
    final doc = await _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('academicYears')
      .doc(yearId)
      .collection('students')
      .doc(studentId)
      .collection('attendance')
        .doc(docId)
        .get();

    final data = doc.data();
    if (data == null) return null;
    return AttendanceStatus.fromString(data['status'] as String?);
  }

  Future<void> setAttendanceForStudent({
    required String yearId,
    String schoolId = AppConfig.schoolId,
    required String teacherUid,
    required String studentId,
    required DateTime date,
    required AttendanceStatus status,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final docId = _dateDocId(normalized);

    final doc = _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('academicYears')
      .doc(yearId)
      .collection('students')
      .doc(studentId)
      .collection('attendance')
        .doc(docId);

    await doc.set({
      'date': Timestamp.fromDate(normalized),
      'status': status.asString,
      'markedBy': teacherUid,
      'markedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setAttendanceBatch({
    required String yearId,
    String schoolId = AppConfig.schoolId,
    required String teacherUid,
    required DateTime date,
    required Map<String, AttendanceStatus> studentStatus,
  }) async {
    final batch = _firestore.batch();
    final normalized = DateTime(date.year, date.month, date.day);
    final docId = _dateDocId(normalized);

    for (final entry in studentStatus.entries) {
      final studentId = entry.key;
      final status = entry.value;

      final doc = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('academicYears')
          .doc(yearId)
          .collection('students')
          .doc(studentId)
          .collection('attendance')
          .doc(docId);

      batch.set(doc, {
        'date': Timestamp.fromDate(normalized),
        'status': status.asString,
        'markedBy': teacherUid,
        'markedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  String _dateDocId(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
