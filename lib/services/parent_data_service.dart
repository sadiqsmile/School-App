import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/attendance_entry.dart';
import '../models/parent_student.dart';
import '../models/student_base.dart';
import '../models/student_year.dart';

class ParentDataService {
  ParentDataService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _yearStudents({
    required String yearId,
    required String schoolId,
  }) {
    return _firestore
        .collection('academicYears')
        .doc(yearId)
        .collection('schools')
        .doc(schoolId)
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

  Stream<List<ParentStudent>> watchMyStudents({
    required String yearId,
    String schoolId = AppConfig.schoolId,
    required String parentUid,
  }) {
    final query = _yearStudents(yearId: yearId, schoolId: schoolId)
        .where('parentUids', arrayContains: parentUid);

    return query.snapshots().asyncMap((snapshot) async {
      final items = <ParentStudent>[];

      for (final doc in snapshot.docs) {
        final year = StudentYear.fromMap(doc.id, doc.data());

        final baseSnap = await _studentBase(schoolId: schoolId, studentId: year.studentId).get();
        final baseData = baseSnap.data() ?? const <String, Object?>{};
        final base = StudentBase.fromMap(year.studentId, baseData);

        items.add(ParentStudent(base: base, year: year));
      }

      items.sort((a, b) => a.base.fullName.compareTo(b.base.fullName));
      return items;
    });
  }

  Stream<List<AttendanceEntry>> watchAttendanceForMonth({
    required String yearId,
    String schoolId = AppConfig.schoolId,
    required String studentId,
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final attendanceRef = _firestore
        .collection('academicYears')
        .doc(yearId)
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .collection('attendance');

    // Recommended: store `date` field as Timestamp for querying.
    final query = attendanceRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end));

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((d) => AttendanceEntry.fromMap(d.id, d.data()))
          .toList();

      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  // ---------- New (Firestore-only) parent linking via parents/{mobile}.children ----------

  /// Watches the parent's linked children IDs from:
  /// `schools/{schoolId}/parents/{mobile}` where `children` is an array of studentIds.
  ///
  /// Then loads base student documents from:
  /// `schools/{schoolId}/students/{studentId}`
  ///
  /// NOTE: This performs one read per child (typically small). This is intentionally
  /// kept simple and free-plan friendly.
  Stream<List<StudentBase>> watchLinkedChildrenBaseStudents({
    String schoolId = AppConfig.schoolId,
    required String parentMobile,
  }) {
    final parentDoc = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('parents')
        .doc(parentMobile);

    return parentDoc.snapshots().asyncMap((snap) async {
      final data = snap.data();
      final children = (data == null ? null : data['children']) as List?;
      final ids = (children ?? const []).whereType<String>().toList();

      final items = <StudentBase>[];
      for (final id in ids) {
        final baseSnap = await _studentBase(schoolId: schoolId, studentId: id).get();
        final baseData = baseSnap.data() ?? const <String, Object?>{};
        items.add(StudentBase.fromMap(id, baseData));
      }

      items.sort((a, b) => a.fullName.compareTo(b.fullName));
      return items;
    });
  }
}
