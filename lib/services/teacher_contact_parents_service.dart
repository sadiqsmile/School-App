import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class StudentParentContactEntry {
  const StudentParentContactEntry({
    required this.studentId,
    required this.studentName,
    required this.groupId,
    required this.classId,
    required this.sectionId,
    required this.parentMobile,
    required this.isActive,
    this.admissionNo,
  });

  final String studentId;
  final String studentName;
  final String groupId;
  final String classId;
  final String sectionId;
  final String parentMobile;
  final bool isActive;
  final String? admissionNo;

  factory StudentParentContactEntry.fromMap(String id, Map<String, Object?> map) {
    final name = (map['name'] as String?)?.trim();
    final legacy = (map['fullName'] as String?)?.trim();

    final groupId = ((map['group'] as String?)?.trim() ?? (map['groupId'] as String?)?.trim()) ?? '';
    final classId = ((map['class'] as String?)?.trim() ?? (map['classId'] as String?)?.trim()) ?? '';
    final sectionId = ((map['section'] as String?)?.trim() ?? (map['sectionId'] as String?)?.trim()) ?? '';

    return StudentParentContactEntry(
      studentId: id,
      studentName: (name == null || name.isEmpty)
          ? ((legacy == null || legacy.isEmpty) ? 'Student' : legacy)
          : name,
      groupId: groupId,
      classId: classId,
      sectionId: sectionId,
      parentMobile: (map['parentMobile'] as String?)?.trim() ?? '',
      admissionNo: (map['admissionNo'] as String?)?.trim(),
      isActive: (map['isActive'] as bool?) ?? true,
    );
  }

  static String cleanMobile(String raw) {
    final onlyDigits = raw.replaceAll(RegExp(r'\D'), '');
    return onlyDigits;
  }

  bool get hasValidIndianMobile {
    final m = cleanMobile(parentMobile);
    return m.length == 10 && int.tryParse(m) != null;
  }

  String get cleanedMobile10 {
    final m = cleanMobile(parentMobile);
    return m.length == 10 ? m : '';
  }
}

class TeacherContactParentsService {
  TeacherContactParentsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  /// Watches students for a given group + class + section.
  ///
  /// Sorting is done client-side to avoid index surprises.
  Stream<List<StudentParentContactEntry>> watchStudentsForGroupClassSection({
    String schoolId = AppConfig.schoolId,
    required String groupId,
    required String classId,
    required String sectionId,
    required bool activeOnly,
  }) {
    Query<Map<String, dynamic>> q = _schoolDoc(schoolId: schoolId)
        .collection('students')
        .where('group', isEqualTo: groupId)
        .where('class', isEqualTo: classId)
        .where('section', isEqualTo: sectionId);

    if (activeOnly) {
      q = q.where('isActive', isEqualTo: true);
    }

    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => StudentParentContactEntry.fromMap(d.id, d.data()))
          .toList(growable: false);

      final sorted = [...list]
        ..sort((a, b) => a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));

      return sorted;
    });
  }
}
