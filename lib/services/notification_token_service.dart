import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class NotificationTokenService {
  NotificationTokenService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String _tokenIdFor(String token) {
    // Use a stable, Firestore-safe doc id.
    final digest = sha1.convert(utf8.encode(token));
    return digest.toString();
  }

  Future<NotificationSettings> ensurePermission() async {
    // On Android 13+ and on Web, permissions matter.
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  /// Registers and persists the current FCM token under:
  /// - parents: schools/{schoolId}/parents/{mobile}/tokens/{tokenId}
  /// - users:   schools/{schoolId}/users/{uid}/tokens/{tokenId}
  ///
  /// Notes:
  /// - If permission is denied or token is null, this does nothing.
  /// - The token doc id is a sha1 hash of the token.
  Future<void> registerParentToken({
    required String parentMobile,
    String schoolId = AppConfig.schoolId,
    String? vapidKey,
  }) async {
    final mobile = parentMobile.trim();
    if (mobile.isEmpty) return;

    await ensurePermission();
    final token = await _messaging.getToken(vapidKey: vapidKey);
    if (token == null || token.trim().isEmpty) return;

    final tokenId = _tokenIdFor(token);
    final ref = _schoolDoc(schoolId: schoolId)
        .collection('parents')
        .doc(mobile)
        .collection('tokens')
        .doc(tokenId);

    await ref.set({
      'token': token,
      'platform': _platformLabel(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Keep it fresh.
    _messaging.onTokenRefresh.listen((newToken) async {
      if (newToken.trim().isEmpty) return;
      final newId = _tokenIdFor(newToken);
      final newRef = _schoolDoc(schoolId: schoolId)
          .collection('parents')
          .doc(mobile)
          .collection('tokens')
          .doc(newId);

      await newRef.set({
        'token': newToken,
        'platform': _platformLabel(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> registerUserToken({
    required String uid,
    String schoolId = AppConfig.schoolId,
    String? vapidKey,
  }) async {
    final cleanedUid = uid.trim();
    if (cleanedUid.isEmpty) return;

    await ensurePermission();
    final token = await _messaging.getToken(vapidKey: vapidKey);
    if (token == null || token.trim().isEmpty) return;

    final tokenId = _tokenIdFor(token);
    final ref = _schoolDoc(schoolId: schoolId)
        .collection('users')
        .doc(cleanedUid)
        .collection('tokens')
        .doc(tokenId);

    await ref.set({
      'token': token,
      'platform': _platformLabel(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _messaging.onTokenRefresh.listen((newToken) async {
      if (newToken.trim().isEmpty) return;
      final newId = _tokenIdFor(newToken);
      final newRef = _schoolDoc(schoolId: schoolId)
          .collection('users')
          .doc(cleanedUid)
          .collection('tokens')
          .doc(newId);

      await newRef.set({
        'token': newToken,
        'platform': _platformLabel(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
