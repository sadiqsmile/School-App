import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('users')
        .doc(uid);
  }

  Stream<AppUser> watchUserProfile(String uid) {
    return _userDoc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        throw StateError('User profile does not exist yet for uid=$uid');
      }
      return AppUser.fromMap(uid: uid, schoolId: AppConfig.schoolId, map: data);
    });
  }

  /// Fetches a user's displayName from `schools/{schoolId}/users/{uid}`.
  ///
  /// Returns null if the profile doc does not exist.
  Future<String?> getUserDisplayNameOrNull(String uid) async {
    final snap = await _userDoc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return data['displayName'] as String?;
  }
}
