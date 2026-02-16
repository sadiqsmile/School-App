import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import 'parent_password_hasher.dart';

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

    final defaultPassword = ParentPasswordHasher.defaultPasswordForMobile(mobile);

    final saltBytes = ParentPasswordHasher.generateSaltBytes();
    final saltB64 = ParentPasswordHasher.saltToBase64(saltBytes);
    final hashB64 = await ParentPasswordHasher.hashPasswordToBase64(
      password: defaultPassword,
      saltBytes: saltBytes,
      version: ParentPasswordHasher.defaultVersion(),
    );

    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('parents')
        .doc(mobile);

    await docRef.set({
      // Keep both keys for compatibility across older/newer UI code.
      'mobile': mobile,
      'phone': mobile,
      'passwordHash': hashB64,
      'passwordSalt': saltB64,
      'passwordVersion': ParentPasswordHasher.defaultVersion(),
      'displayName': displayName.trim(),
      'role': 'parent',
      'isActive': true,
      'children': [],
      'failedAttempts': 0,
      'lockUntil': FieldValue.delete(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return CreateParentResult(
      mobile: mobile,
      defaultPassword: defaultPassword,
    );
  }

  /// Admin reset parent password to default (last 4 digits of mobile).
  ///
  /// Stores the password securely (PBKDF2) and clears lockout counters.
  /// Returns the new plaintext password so the admin can communicate it.
  Future<String> resetParentPasswordToDefault({
    String schoolId = AppConfig.schoolId,
    required String mobile,
  }) async {
    final m = mobile.trim();
    if (m.length < 4) throw Exception('Invalid mobile number');

    final newPassword = ParentPasswordHasher.defaultPasswordForMobile(m);
    final saltBytes = ParentPasswordHasher.generateSaltBytes();
    final saltB64 = ParentPasswordHasher.saltToBase64(saltBytes);
    final hashB64 = await ParentPasswordHasher.hashPasswordToBase64(
      password: newPassword,
      saltBytes: saltBytes,
      version: ParentPasswordHasher.defaultVersion(),
    );

    final ref = _firestore.collection('schools').doc(schoolId).collection('parents').doc(m);
    await ref.set({
      'passwordHash': hashB64,
      'passwordSalt': saltB64,
      'passwordVersion': ParentPasswordHasher.defaultVersion(),
      'password': FieldValue.delete(),
      'failedAttempts': 0,
      'lockUntil': FieldValue.delete(),
      'passwordResetAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return newPassword;
  }
}