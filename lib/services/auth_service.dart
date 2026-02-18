import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import 'parent_password_hasher.dart';
import '../utils/parent_auth_email.dart';

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
  // Parent (FirebaseAuth login via generated email; no OTP, no Functions)
  // ---------------------------
  Future<void> signInParent({
    required String phoneNumber,
    required String password,
    void Function(String message)? onStatus,
  }) async {
    onStatus?.call('Signing in…');

    final mobile = digitsOnly(phoneNumber);
    final pass = password.trim();

    if (mobile.length != 10 || int.tryParse(mobile) == null) {
      throw Exception('Enter a valid 10-digit mobile number');
    }
    if (pass.isEmpty) {
      throw Exception('Password is required');
    }

    final parentEmail = parentEmailFromMobile(mobile);

    // 1) Try normal FirebaseAuth sign-in first.
    try {
      await _auth.signInWithEmailAndPassword(email: parentEmail, password: pass);
      onStatus?.call('Finishing setup…');
      await _postParentAuthSignIn(mobile: mobile, onStatus: onStatus);
      return;
    } on FirebaseAuthException catch (e) {
      // Continue to migration flow only if the auth user doesn't exist yet.
      if (e.code != 'user-not-found') {
        // Firebase can return invalid-credential / wrong-password / too-many-requests, etc.
        rethrow;
      }
    }

    // 2) First-time migration flow:
    // - validate legacy password stored under schools/{schoolId}/parents/{mobile}
    // - create FirebaseAuth user with generated email + same password
    // - store authUid into parent doc
    onStatus?.call('Upgrading account…');
    await _migrateParentToFirebaseAuth(
      mobile: mobile,
      password: pass,
      parentEmail: parentEmail,
      onStatus: onStatus,
    );
  }

  Future<void> signOutParent() async => _auth.signOut();

  // ---------------------------
  // Parent password management
  // ---------------------------

  /// Change password for the currently logged-in parent (stored in SharedPreferences).
  ///
  /// New design: parent is a FirebaseAuth user (email = mobile@parents.hongirana.school).
  ///
  /// - Reauthenticates with old password
  /// - Updates FirebaseAuth password
  /// - Clears any `forcePasswordReset` flag in Firestore parent profile
  Future<void> changeMyParentPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Please login again');

    final email = (user.email ?? '').trim();
    if (email.isEmpty) throw Exception('Your account email is missing');

    final oldPass = oldPassword.trim();
    final newPass = newPassword.trim();
    if (oldPass.isEmpty) throw Exception('Old password is required');
    if (newPass.isEmpty) throw Exception('New password is required');
    if (newPass.length < 6) throw Exception('New password must be at least 6 characters');
    if (newPass == oldPass) throw Exception('New password must be different');

    final credential = EmailAuthProvider.credential(email: email, password: oldPass);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPass);

    final mobile = tryExtractMobileFromParentEmail(email);
    if (mobile != null) {
      final parentRef = _parentDoc(mobile: mobile);
      try {
        await parentRef.set({
          'updatedAt': FieldValue.serverTimestamp(),
          'forcePasswordReset': false,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Change password for a parent mobile.
  Future<void> changeParentPassword({
    required String mobile,
    required String oldPassword,
    required String newPassword,
    String schoolId = AppConfig.schoolId,
  }) async {
    // With FirebaseAuth-based parents, you cannot securely change another user's
    // password from the client. Keep this method for backward compatibility.
    throw Exception('Not supported. Please change password from the parent account.');
  }

  /// Returns the current signed-in parent's mobile number (10 digits) based on
  /// the generated FirebaseAuth email, or null if not a parent session.
  Future<String?> getParentMobile() async {
    final user = _auth.currentUser;
    return tryExtractMobileFromParentEmail(user?.email);
  }

  // ---------------------------
  // Common Signout
  // ---------------------------
  Future<void> signOut() async {
    // Parent sessions are also FirebaseAuth sessions now.
    await _auth.signOut();
  }

  // ---------------------------
  // Helpers
  // ---------------------------

  DocumentReference<Map<String, dynamic>> _parentDoc({
    required String mobile,
    String schoolId = AppConfig.schoolId,
  }) {
    return _firestore.collection('schools').doc(schoolId).collection('parents').doc(mobile);
  }

  Future<void> _postParentAuthSignIn({
    required String mobile,
    void Function(String message)? onStatus,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Login failed');

    final ref = _parentDoc(mobile: mobile);
    final snap = await ref.get();
    if (!snap.exists) {
      // Auth user exists but profile missing.
      await _auth.signOut();
      throw Exception('Parent profile not found. Contact admin.');
    }

    final data = snap.data() ?? const <String, dynamic>{};
    final isActive = (data['isActive'] ?? false) == true;
    if (!isActive) {
      await _auth.signOut();
      throw Exception('Parent account is disabled');
    }

    onStatus?.call('Setting up your profile…');

    // Ensure authUid is attached (idempotent).
    final authUid = (data['authUid'] as String?)?.trim();
    if (authUid == null || authUid.isEmpty || authUid != user.uid) {
      try {
        await ref.set({
          'authUid': user.uid,
          'mobile': mobile,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        // Without authUid, parent rules will fail; sign out and surface a clear error.
        await _auth.signOut();
        throw Exception('Account setup failed (authUid). Please update Firestore rules and try again. Details: $e');
      }
    }

    // Ensure a role profile exists so app routing treats parent as a normal user.
    // This should NOT be best-effort; if it fails, the app can't route safely.
    final displayName = (data['displayName'] as String?)?.trim();
    final userRef = _firestore
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('users')
        .doc(user.uid);
    try {
      await userRef.set({
        'uid': user.uid,
        'role': 'parent',
        'displayName': (displayName == null || displayName.isEmpty) ? 'Parent' : displayName,
        'email': (user.email ?? '').trim().isEmpty ? null : (user.email ?? '').trim(),
        'phone': mobile,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      await _auth.signOut();
      throw Exception('Account setup failed (user profile). Please update Firestore rules and try again. Details: $e');
    }

    // Persist parent scoping info into the user profile so strict rules can
    // authorize reads (e.g., homework) by child class/section.
    try {
      onStatus?.call('Syncing class access…');
      final children = (data['children'] as List?)?.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? const <String>[];

      final classSectionIds = <String>{};
      for (final studentId in children) {
        final base = await _firestore
            .collection('schools')
            .doc(AppConfig.schoolId)
            .collection('students')
            .doc(studentId)
            .get();

        final baseData = base.data();
        if (baseData == null) continue;

        final classId = (baseData['class'] as String?)?.trim() ?? (baseData['classId'] as String?)?.trim();
        final sectionId = (baseData['section'] as String?)?.trim() ?? (baseData['sectionId'] as String?)?.trim();

        if (classId == null || classId.isEmpty) continue;
        if (sectionId == null || sectionId.isEmpty) continue;
        classSectionIds.add('${classId}_$sectionId');
      }

      await userRef.set({
        'childStudentIds': children,
        'childClassSectionIds': classSectionIds.toList()..sort(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      await _auth.signOut();
      throw Exception('Account setup failed (class access). Please ask admin to update Firestore rules and student profiles. Details: $e');
    }

    // Best-effort: add auth UID into year-student docs so parents can read their data
    // even if existing data used legacy mobile in `parentUids`.
    try {
      onStatus?.call('Syncing access…');
      await _ensureParentUidInYearStudents(mobile: mobile, authUid: user.uid);
    } catch (_) {}
  }

  Future<void> _migrateParentToFirebaseAuth({
    required String mobile,
    required String password,
    required String parentEmail,
    void Function(String message)? onStatus,
  }) async {
    final parentRef = _parentDoc(mobile: mobile);
    final doc = await parentRef.get();
    if (!doc.exists) {
      throw Exception('Parent mobile number not found');
    }
    final data = doc.data() ?? const <String, dynamic>{};

    final isActive = (data['isActive'] ?? false) == true;
    if (!isActive) {
      throw Exception('Parent account is disabled');
    }

    await _verifyLegacyParentPasswordOrThrow(parentRef: parentRef, data: data, password: password);

    // Create FirebaseAuth account.
    try {
      onStatus?.call('Creating secure login…');
      await _auth.createUserWithEmailAndPassword(email: parentEmail, password: password);
    } on FirebaseAuthException catch (e) {
      // Race condition: account created elsewhere between checks.
      if (e.code == 'email-already-in-use') {
        onStatus?.call('Signing in…');
        await _auth.signInWithEmailAndPassword(email: parentEmail, password: password);
      } else {
        rethrow;
      }
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Migration sign-in failed');

    // Persist authUid and remove plaintext password field if present.
    final update = <String, Object?>{
      'authUid': user.uid,
      'mobile': mobile,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final plain = (data['password'] ?? '').toString().trim();
    if (plain.isNotEmpty) {
      update['password'] = FieldValue.delete();
    }

    try {
      onStatus?.call('Linking your account…');
      await parentRef.set(update, SetOptions(merge: true));
    } catch (_) {
      // If this fails due to current rules, parent is still signed in.
      // Admin should update rules and then the app can attach authUid.
    }

    onStatus?.call('Finishing setup…');
    await _postParentAuthSignIn(mobile: mobile, onStatus: onStatus);
  }

  Future<void> _verifyLegacyParentPasswordOrThrow({
    required DocumentReference<Map<String, dynamic>> parentRef,
    required Map<String, dynamic> data,
    required String password,
  }) async {
    // Rate limiting / lockout (best-effort writes).
    final lockUntilTs = data['lockUntil'];
    if (lockUntilTs is Timestamp) {
      final lockUntil = lockUntilTs.toDate();
      if (DateTime.now().isBefore(lockUntil)) {
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
      try {
        await parentRef.set(update, SetOptions(merge: true));
      } catch (_) {}
    }

    Future<void> recordSuccessCleanup() async {
      try {
        await parentRef.set({
          'failedAttempts': 0,
          'lockUntil': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    final pass = password.trim();

    // Prefer secure hash if present.
    final passwordHash = (data['passwordHash'] ?? '').toString().trim();
    final passwordSalt = (data['passwordSalt'] ?? '').toString().trim();
    final passwordVersion = (data['passwordVersion'] is num)
        ? (data['passwordVersion'] as num).toInt()
        : ParentPasswordHasher.defaultVersion();

    bool ok;
    if (passwordHash.isNotEmpty) {
      if (passwordSalt.isEmpty) {
        await recordFailure();
        throw Exception('Wrong password');
      }
      ok = await ParentPasswordHasher.verify(
        password: pass,
        passwordHashBase64: passwordHash,
        passwordSaltBase64: passwordSalt,
        version: passwordVersion,
      );
    } else {
      final savedPassword = (data['password'] ?? '').toString();
      ok = savedPassword.isNotEmpty && savedPassword == pass;
    }

    if (!ok) {
      await recordFailure();
      throw Exception('Wrong password');
    }

    await recordSuccessCleanup();
  }

  Future<void> _ensureParentUidInYearStudents({
    required String mobile,
    required String authUid,
    String schoolId = AppConfig.schoolId,
  }) async {
    // Determine active year.
    final settingsDoc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('settings')
        .doc('app')
        .get();
    final data = settingsDoc.data();
    final yearId = (data == null ? null : data['activeAcademicYearId'] as String?) ?? AppConfig.fallbackAcademicYearId;

    final yearStudents = _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('academicYears')
      .doc(yearId)
      .collection('students');

    // Query by legacy mobile and union in authUid.
    Query<Map<String, dynamic>> q = yearStudents.where('parentUids', arrayContains: mobile).limit(200);

    while (true) {
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.set(d.reference, {
          'parentUids': FieldValue.arrayUnion([authUid]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();

      // Paginate.
      final last = snap.docs.last;
      q = yearStudents
          .where('parentUids', arrayContains: mobile)
          .startAfterDocument(last)
          .limit(200);
    }

    // Also attach to base student docs that store parentMobile.
    Query<Map<String, dynamic>> baseQ = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('parentMobile', isEqualTo: mobile)
        .limit(200);

    while (true) {
      final snap = await baseQ.get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.set(d.reference, {
          'parentAuthUid': authUid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      final last = snap.docs.last;
      baseQ = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('parentMobile', isEqualTo: mobile)
          .startAfterDocument(last)
          .limit(200);
    }
  }
}