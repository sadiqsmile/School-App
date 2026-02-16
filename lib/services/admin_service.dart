import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class CreateParentResult {
  const CreateParentResult({
    required this.mobile,
    required this.defaultPassword,
  });

  final String mobile;
  final String defaultPassword;
}

class AdminService {
  AdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// FREE METHOD:
  /// Creates a teacher profile document in Firestore.
  /// (Teacher Auth account must be created manually in Firebase Auth for now.)
  Future<void> createTeacherProfile({
    String schoolId = AppConfig.schoolId,
    required String teacherUid, // Firebase Auth UID
    required String email,
    required String displayName,
    String? phone,
    List<String> assignedGroups = const <String>[],
  }) async {
    final usersDoc = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .doc(teacherUid);

    final teachersDoc = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .doc(teacherUid);

    final payload = {
      'role': 'teacher',
      'displayName': displayName.trim(),
      'email': email.trim(),
      'phone': phone?.trim(),
      'assignedGroups': assignedGroups,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Keep both collections in sync:
    // - users/{uid}: used for routing + role checks.
    // - teachers/{uid}: used for admin listing and assignments.
    await Future.wait([
      usersDoc.set(payload, SetOptions(merge: true)),
      teachersDoc.set(payload, SetOptions(merge: true)),
    ]);
  }

  /// FREE METHOD:
  /// Creates a parent document in Firestore with default password = last 4 digits.
  Future<CreateParentResult> createParent({
    String schoolId = AppConfig.schoolId,
    required String phone,
    required String displayName,
  }) async {
    final mobile = phone.trim();
    if (mobile.length < 4) {
      throw Exception("Invalid mobile number");
    }

    final defaultPassword = mobile.substring(mobile.length - 4);

    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('parents')
        .doc(mobile);

    await docRef.set({
      // Keep both keys for compatibility across older/newer UI code.
      'mobile': mobile,
      'phone': mobile,
      'password': defaultPassword,
      'displayName': displayName.trim(),
      'role': 'parent',
      'isActive': true,
      'children': [],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return CreateParentResult(
      mobile: mobile,
      defaultPassword: defaultPassword,
    );
  }
}