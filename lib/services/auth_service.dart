import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

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

    final doc = await _firestore
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('parents')
        .doc(mobile)
        .get();

    if (!doc.exists) {
      throw Exception("Parent mobile number not found");
    }

    final data = doc.data() as Map<String, dynamic>;

    final isActive = (data['isActive'] ?? false) == true;
    if (!isActive) {
      throw Exception("Parent account is disabled");
    }

    final savedPassword = (data['password'] ?? '').toString();
    if (savedPassword != pass) {
      throw Exception("Wrong password");
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