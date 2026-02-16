import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'parent_password_hasher.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // ---------------------------
  // Teacher/Admin (Firebase Auth)
  // ---------------------------
  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ---------------------------
  // Parent (Firestore login - NO Functions)
  // ---------------------------
  Future<void> signInParent({
    required String phoneNumber,
    required String password,
  }) async {
    final mobile = phoneNumber.trim();
    final pass = password.trim();

    if (mobile.isEmpty || pass.isEmpty) {
      throw Exception('Mobile and password are required');
    }

    final parentRef = _firestore
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('parents')
        .doc(mobile);

    final doc = await parentRef.get();

    if (!doc.exists) {
      throw Exception("Parent mobile number not found");
    }

    final data = doc.data() as Map<String, dynamic>;

    final isActive = (data['isActive'] ?? false) == true;
    if (!isActive) {
      throw Exception("Parent account is disabled");
    }

    // Rate limiting / lockout.
    final lockUntilTs = data['lockUntil'];
    if (lockUntilTs is Timestamp) {
      final lockUntil = lockUntilTs.toDate();
      final now = DateTime.now();
      if (now.isBefore(lockUntil)) {
        throw Exception('Account locked. Try again later.');
      }
    }

    final failedAttempts = (data['failedAttempts'] is num) ? (data['failedAttempts'] as num).toInt() : 0;
    const maxAttempts = 5;
    const lockMinutes = 10;

    Future<void> recordFailure() async {
      final next = failedAttempts + 1;
      final update = <String, Object?>{
        'failedAttempts': next,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (next >= maxAttempts) {
        update['lockUntil'] = Timestamp.fromDate(DateTime.now().add(const Duration(minutes: lockMinutes)));
      }

      // Best-effort; login flow should still throw the auth error even if this write is blocked.
      try {
        await parentRef.set(update, SetOptions(merge: true));
      } catch (_) {}
    }

    Future<void> recordSuccessAndCleanup({bool deletePlaintext = false}) async {
      final update = <String, Object?>{
        'failedAttempts': 0,
        'lockUntil': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (deletePlaintext) {
        update['password'] = FieldValue.delete();
      }

      try {
        await parentRef.set(update, SetOptions(merge: true));
      } catch (_) {}
    }

    // Prefer secure hash if present.
    final passwordHash = (data['passwordHash'] ?? '').toString().trim();
    final passwordSalt = (data['passwordSalt'] ?? '').toString().trim();
    final passwordVersion = (data['passwordVersion'] is num)
        ? (data['passwordVersion'] as num).toInt()
        : ParentPasswordHasher.defaultVersion();

    if (passwordHash.isNotEmpty) {
      if (passwordSalt.isEmpty) {
        // Corrupted state; treat as auth failure.
        await recordFailure();
        throw Exception('Wrong password');
      }

      final ok = await ParentPasswordHasher.verify(
        password: pass,
        passwordHashBase64: passwordHash,
        passwordSaltBase64: passwordSalt,
        version: passwordVersion,
      );

      if (!ok) {
        await recordFailure();
        throw Exception('Wrong password');
      }

      // If legacy plaintext still exists, remove it now.
      final hasPlain = (data['password'] != null) && (data['password'] ?? '').toString().trim().isNotEmpty;
      await recordSuccessAndCleanup(deletePlaintext: hasPlain);
    } else {
      // Legacy plaintext password path (auto-migrate on successful login).
      final savedPassword = (data['password'] ?? '').toString();
      if (savedPassword.isEmpty) {
        await recordFailure();
        throw Exception('Password not set for this parent');
      }
      if (savedPassword != pass) {
        await recordFailure();
        throw Exception('Wrong password');
      }

      // Migrate to secure hash.
      final saltBytes = ParentPasswordHasher.generateSaltBytes();
      final saltB64 = ParentPasswordHasher.saltToBase64(saltBytes);
      final hashB64 = await ParentPasswordHasher.hashPasswordToBase64(
        password: pass,
        saltBytes: saltBytes,
        version: ParentPasswordHasher.defaultVersion(),
      );

      // Store secure fields and delete plaintext.
      try {
        await parentRef.set({
          'passwordHash': hashB64,
          'passwordSalt': saltB64,
          'passwordVersion': ParentPasswordHasher.defaultVersion(),
          'password': FieldValue.delete(),
          'failedAttempts': 0,
          'lockUntil': FieldValue.delete(),
          'passwordMigratedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // If migration fails due to rules, still allow login so existing parents are not broken.
      }
    }

    // Save parent session locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('schoolId', AppConfig.schoolId);
    await prefs.setString('parentMobile', mobile);
    await prefs.setString('parentRole', 'parent');
  }

  Future<void> signOutParent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('schoolId');
    await prefs.remove('parentMobile');
    await prefs.remove('parentRole');
  }

  // ---------------------------
  // Parent password management
  // ---------------------------

  /// Change password for the currently logged-in parent (stored in SharedPreferences).
  ///
  /// - Verifies old password (supports hashed or legacy plaintext)
  /// - Stores new password securely (PBKDF2)
  /// - Deletes legacy plaintext password field if present
  Future<void> changeMyParentPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final mobile = await getParentMobile();
    if (mobile == null || mobile.trim().isEmpty) {
      throw Exception('Please login again');
    }
    await changeParentPassword(
      mobile: mobile,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  /// Change password for a parent mobile.
  Future<void> changeParentPassword({
    required String mobile,
    required String oldPassword,
    required String newPassword,
    String schoolId = AppConfig.schoolId,
  }) async {
    final m = mobile.trim();
    final oldPass = oldPassword.trim();
    final newPass = newPassword.trim();

    if (m.isEmpty) throw Exception('Mobile is required');
    if (oldPass.isEmpty) throw Exception('Old password is required');
    if (newPass.isEmpty) throw Exception('New password is required');
    if (newPass.length < 6) throw Exception('New password must be at least 6 characters');
    if (newPass == oldPass) throw Exception('New password must be different');

    final parentRef = _firestore.collection('schools').doc(schoolId).collection('parents').doc(m);
    final snap = await parentRef.get();
    if (!snap.exists) throw Exception('Parent not found');
    final data = snap.data() as Map<String, dynamic>;

    final isActive = (data['isActive'] ?? false) == true;
    if (!isActive) throw Exception('Parent account is disabled');

    final lockUntilTs = data['lockUntil'];
    if (lockUntilTs is Timestamp) {
      final lockUntil = lockUntilTs.toDate();
      if (DateTime.now().isBefore(lockUntil)) {
        throw Exception('Account locked. Try again later.');
      }
    }

    // Verify old password.
    final passwordHash = (data['passwordHash'] ?? '').toString().trim();
    final passwordSalt = (data['passwordSalt'] ?? '').toString().trim();
    final passwordVersion = (data['passwordVersion'] is num)
        ? (data['passwordVersion'] as num).toInt()
        : ParentPasswordHasher.defaultVersion();

    bool ok = false;
    if (passwordHash.isNotEmpty) {
      if (passwordSalt.isEmpty) throw Exception('Password data is corrupted');
      ok = await ParentPasswordHasher.verify(
        password: oldPass,
        passwordHashBase64: passwordHash,
        passwordSaltBase64: passwordSalt,
        version: passwordVersion,
      );
    } else {
      final plain = (data['password'] ?? '').toString();
      ok = plain.isNotEmpty && plain == oldPass;
    }

    if (!ok) {
      // Reuse same failure tracking logic as sign-in.
      final failedAttempts = (data['failedAttempts'] is num) ? (data['failedAttempts'] as num).toInt() : 0;
      const maxAttempts = 5;
      const lockMinutes = 10;
      final next = failedAttempts + 1;
      final update = <String, Object?>{
        'failedAttempts': next,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (next >= maxAttempts) {
        update['lockUntil'] = Timestamp.fromDate(DateTime.now().add(const Duration(minutes: lockMinutes)));
      }
      try {
        await parentRef.set(update, SetOptions(merge: true));
      } catch (_) {}
      throw Exception('Wrong password');
    }

    // Store new secure password.
    final saltBytes = ParentPasswordHasher.generateSaltBytes();
    final saltB64 = ParentPasswordHasher.saltToBase64(saltBytes);
    final hashB64 = await ParentPasswordHasher.hashPasswordToBase64(
      password: newPass,
      saltBytes: saltBytes,
      version: ParentPasswordHasher.defaultVersion(),
    );

    await parentRef.set({
      'passwordHash': hashB64,
      'passwordSalt': saltB64,
      'passwordVersion': ParentPasswordHasher.defaultVersion(),
      'password': FieldValue.delete(),
      'failedAttempts': 0,
      'lockUntil': FieldValue.delete(),
      'passwordChangedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isParentLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('parentRole') == 'parent' &&
        (prefs.getString('parentMobile') ?? '').isNotEmpty;
  }

  Future<String?> getParentMobile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('parentMobile');
  }

  // ---------------------------
  // Common Signout
  // ---------------------------
  Future<void> signOut() async {
    // Clear any parent session (SharedPreferences) and also sign out Firebase Auth.
    // This keeps the app consistent regardless of which role is currently signed in.
    await signOutParent();
    await _auth.signOut();
  }
}