import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class AdminDataService {
  AdminDataService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  // ---------- Users ----------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchParents({String schoolId = AppConfig.schoolId}) {
    return schoolDoc(schoolId: schoolId).collection('parents').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTeachers({String schoolId = AppConfig.schoolId}) {
    return schoolDoc(schoolId: schoolId).collection('teachers').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchStudents({String schoolId = AppConfig.schoolId}) {
    return schoolDoc(schoolId: schoolId).collection('students').snapshots();
  }

  // ---------- Class/Section ----------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchClasses({String schoolId = AppConfig.schoolId}) {
    return schoolDoc(schoolId: schoolId).collection('classes').orderBy('sortOrder').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSections({String schoolId = AppConfig.schoolId}) {
    return schoolDoc(schoolId: schoolId).collection('sections').orderBy('sortOrder').snapshots();
  }

  Future<void> upsertClass({
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String name,
    required int sortOrder,
  }) {
    return schoolDoc(schoolId: schoolId).collection('classes').doc(classId).set({
      'name': name,
      'sortOrder': sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertSection({
    String schoolId = AppConfig.schoolId,
    required String sectionId,
    required String name,
    required int sortOrder,
  }) {
    return schoolDoc(schoolId: schoolId).collection('sections').doc(sectionId).set({
      'name': name,
      'sortOrder': sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Academic year ----------

  Future<void> setActiveAcademicYearId({
    String schoolId = AppConfig.schoolId,
    required String yearId,
  }) {
    return schoolDoc(schoolId: schoolId).collection('settings').doc('app').set({
      'activeAcademicYearId': yearId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchAppSettings({
    String schoolId = AppConfig.schoolId,
  }) {
    return schoolDoc(schoolId: schoolId).collection('settings').doc('app').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchYearClassSections({
    required String yearId,
    String schoolId = AppConfig.schoolId,
  }) {
    return _firestore
        .collection('academicYears')
        .doc(yearId)
        .collection('schools')
        .doc(schoolId)
        .collection('classSections')
        .orderBy('label')
        .snapshots();
  }

  Future<void> upsertYearClassSection({
    required String yearId,
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String sectionId,
    required String label,
  }) {
    final classSectionId = '${classId}_$sectionId';

    return _firestore
        .collection('academicYears')
        .doc(yearId)
        .collection('schools')
        .doc(schoolId)
        .collection('classSections')
        .doc(classSectionId)
        .set({
      'classId': classId,
      'sectionId': sectionId,
      'label': label,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> assignStudentToYear({
    required String yearId,
    String schoolId = AppConfig.schoolId,
    required String studentId,
    required String classSectionId,
    int? rollNo,
    required List<String> parentUids,
  }) {
    return _firestore
        .collection('academicYears')
        .doc(yearId)
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .set({
      'studentId': studentId,
      'classSectionId': classSectionId,
      'rollNo': rollNo,
      'parentUids': parentUids,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setTeacherAssignments({
    String schoolId = AppConfig.schoolId,
    required String teacherUid,
    required List<String> classSectionIds,
  }) {
    return schoolDoc(schoolId: schoolId)
        .collection('teacherAssignments')
        .doc(teacherUid)
        .set({
      'classSectionIds': classSectionIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<DocumentReference<Map<String, dynamic>>> createStudent({
    String schoolId = AppConfig.schoolId,
    required String fullName,
    String? admissionNo,
  }) {
    return schoolDoc(schoolId: schoolId).collection('students').add({
      // Keep both keys for compatibility, but prefer `name` going forward.
      'name': fullName.trim(),
      'fullName': fullName.trim(),
      'admissionNo': admissionNo?.trim(),
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  // ---------- Admin module (Students v2) ----------

  /// Watches all base students in the school.
  ///
  /// NOTE: searching (contains) is done client-side in UI for now.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchBaseStudents({
    String schoolId = AppConfig.schoolId,
  }) {
    return schoolDoc(schoolId: schoolId)
        .collection('students')
        .orderBy('name')
        .snapshots();
  }

  /// Creates a student document with Auto-ID under:
  /// `schools/{schoolId}/students/{autoId}`
  ///
  /// Requirements handled:
  /// - admissionNo must be unique (enforced via `admissionNumbers/{admissionNo}`)
  /// - store base fields + class/section + parentMobile + isActive
  /// - update/create parent doc at `parents/{mobile}` and add studentId to `children`
  Future<String> createStudentAndLinkParent({
    String schoolId = AppConfig.schoolId,
    required String admissionNo,
    required String fullName,
    required String groupId,
    required String classId,
    required String sectionId,
    required String parentMobile,
    String? parentDisplayName,
    required bool isActive,
  }) async {
    final cleanedAdmission = admissionNo.trim();
    final cleanedName = fullName.trim();
    final cleanedGroupId = groupId.trim();
    final cleanedClassId = classId.trim();
    final cleanedSectionId = sectionId.trim();
    final cleanedMobile = parentMobile.trim();
    final cleanedParentName = parentDisplayName?.trim();

    if (cleanedAdmission.isEmpty) {
      throw Exception('Admission number is required');
    }
    if (cleanedName.isEmpty) {
      throw Exception('Student name is required');
    }
    if (cleanedClassId.isEmpty) {
      throw Exception('Class is required');
    }
    if (cleanedSectionId.isEmpty) {
      throw Exception('Section is required');
    }
    if (cleanedGroupId.isEmpty) {
      throw Exception('Group is required');
    }
    if (cleanedMobile.length != 10) {
      throw Exception('Parent mobile must be 10 digits');
    }
    if (int.tryParse(cleanedMobile) == null) {
      throw Exception('Parent mobile must contain only digits');
    }

    final school = schoolDoc(schoolId: schoolId);
    final studentsCol = school.collection('students');
    final admissionIndexDoc = school.collection('admissionNumbers').doc(cleanedAdmission);
    final parentDoc = school.collection('parents').doc(cleanedMobile);

    return _firestore.runTransaction<String>((tx) async {
      final admissionSnap = await tx.get(admissionIndexDoc);
      if (admissionSnap.exists) {
        throw Exception('Admission number already exists');
      }

      final newStudentRef = studentsCol.doc();

      tx.set(newStudentRef, {
        'admissionNo': cleanedAdmission,
        // Required fields (must follow spec)
        'name': cleanedName,
        'group': cleanedGroupId,
        'class': cleanedClassId,
        'section': cleanedSectionId,
        'parentMobile': cleanedMobile,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Enforce uniqueness by creating a dedicated index document.
      tx.set(admissionIndexDoc, {
        'studentId': newStudentRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final parentSnap = await tx.get(parentDoc);
      if (parentSnap.exists) {
        final update = <String, Object?>{
          'children': FieldValue.arrayUnion([newStudentRef.id]),
        };
        if (cleanedParentName != null && cleanedParentName.isNotEmpty) {
          update['displayName'] = cleanedParentName;
        }

        tx.set(parentDoc, update, SetOptions(merge: true));
      } else {
        final defaultPassword = cleanedMobile.substring(cleanedMobile.length - 4);
        tx.set(parentDoc, {
          'mobile': cleanedMobile,
          'password': defaultPassword,
          'displayName': (cleanedParentName == null || cleanedParentName.isEmpty)
              ? 'Parent'
              : cleanedParentName,
          'role': 'parent',
          'isActive': true,
          'children': [newStudentRef.id],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return newStudentRef.id;
    });
  }
}
