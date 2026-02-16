import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/app_config.dart';

class MessagingService {
  MessagingService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  Future<void> initForSignedInUser({required String uid}) async {
    try {
      await _messaging.requestPermission();
    } catch (_) {
      // Web/Safari permissions can behave differently; ignore for now.
    }

    String? token;
    try {
      token = await _messaging.getToken(
        vapidKey: null,
      );
    } catch (_) {
      token = null;
    }

    if (token == null) return;

    final tokenDoc = _firestore
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token);

    await tokenDoc.set({
      'token': token,
      'createdAt': FieldValue.serverTimestamp(),
      'platform': 'flutter',
    }, SetOptions(merge: true));
  }
}
