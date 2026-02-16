import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class TimetableService {
  TimetableService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  /// Doc path as required:
  /// schools/{schoolId}/academicYears/{yearId}/timetables/{groupId}/{classId}/{sectionId}
  DocumentReference<Map<String, dynamic>> timetableDoc({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String groupId,
    required String classId,
    required String sectionId,
  }) {
    return _schoolDoc(schoolId: schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('timetables')
        .doc(groupId)
        .collection(classId)
        .doc(sectionId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTimetable({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String groupId,
    required String classId,
    required String sectionId,
  }) {
    return timetableDoc(
      schoolId: schoolId,
      yearId: yearId,
      groupId: groupId,
      classId: classId,
      sectionId: sectionId,
    ).snapshots();
  }

  Future<void> upsertTimetable({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String groupId,
    required String classId,
    required String sectionId,
    required Map<String, List<Map<String, Object?>>> days,
  }) {
    final doc = timetableDoc(
      schoolId: schoolId,
      yearId: yearId,
      groupId: groupId,
      classId: classId,
      sectionId: sectionId,
    );

    return doc.set({
      'groupId': groupId,
      'class': classId,
      'section': sectionId,
      'days': days,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class TimetableDays {
  static const keys = <String>['mon', 'tue', 'wed', 'thu', 'fri'];

  static String label(String key) {
    return switch (key) {
      'mon' => 'Mon',
      'tue' => 'Tue',
      'wed' => 'Wed',
      'thu' => 'Thu',
      'fri' => 'Fri',
      _ => key,
    };
  }
}
