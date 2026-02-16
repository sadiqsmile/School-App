import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

enum NotificationScope {
  school,
  group,
  classSection,
  parent,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scope,
    required this.createdAt,
    this.groupId,
    this.classId,
    this.sectionId,
    this.parentMobile,
    this.createdByUid,
    this.createdByName,
    this.createdByRole,
  });

  final String id;
  final String title;
  final String body;
  final NotificationScope scope;
  final DateTime? createdAt;

  final String? groupId;
  final String? classId;
  final String? sectionId;
  final String? parentMobile;

  final String? createdByUid;
  final String? createdByName;
  final String? createdByRole;

  static NotificationScope _scopeFrom(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'school':
        return NotificationScope.school;
      case 'group':
        return NotificationScope.group;
      case 'classSection':
        return NotificationScope.classSection;
      case 'parent':
        return NotificationScope.parent;
      default:
        return NotificationScope.school;
    }
  }

  static String scopeLabel(NotificationScope s) {
    switch (s) {
      case NotificationScope.school:
        return 'Whole school';
      case NotificationScope.group:
        return 'Group';
      case NotificationScope.classSection:
        return 'Class/Section';
      case NotificationScope.parent:
        return 'Parent';
    }
  }

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, Object?>{};

    final ts = data['createdAt'];
    DateTime? createdAt;
    if (ts is Timestamp) createdAt = ts.toDate();

    return AppNotification(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? 'Notification',
      body: (data['body'] as String?)?.trim() ?? '',
      scope: _scopeFrom(data['scope'] as String?),
      createdAt: createdAt,
      groupId: (data['groupId'] as String?)?.trim(),
      classId: (data['classId'] as String?)?.trim(),
      sectionId: (data['sectionId'] as String?)?.trim(),
      parentMobile: (data['parentMobile'] as String?)?.trim(),
      createdByUid: (data['createdByUid'] as String?)?.trim(),
      createdByName: (data['createdByName'] as String?)?.trim(),
      createdByRole: (data['createdByRole'] as String?)?.trim(),
    );
  }
}

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  /// A simple, reliable inbox feed (no OR queries): we stream latest N notifications
  /// and filter client-side based on role/group/class/parent.
  Stream<List<AppNotification>> watchLatest({
    String schoolId = AppConfig.schoolId,
    int limit = 200,
  }) {
    return _schoolDoc(schoolId: schoolId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs.map(AppNotification.fromDoc).toList(growable: false);
    });
  }

  Future<String> createNotification({
    String schoolId = AppConfig.schoolId,
    required String title,
    required String body,
    required NotificationScope scope,
    String? groupId,
    String? classId,
    String? sectionId,
    String? parentMobile,
    String? createdByUid,
    String? createdByName,
    String? createdByRole,
  }) async {
    final cleanedTitle = title.trim();
    final cleanedBody = body.trim();
    if (cleanedTitle.isEmpty) throw Exception('Title is required');
    if (cleanedBody.isEmpty) throw Exception('Message is required');

    final payload = <String, Object?>{
      'title': cleanedTitle,
      'body': cleanedBody,
      'scope': switch (scope) {
        NotificationScope.school => 'school',
        NotificationScope.group => 'group',
        NotificationScope.classSection => 'classSection',
        NotificationScope.parent => 'parent',
      },
      'groupId': groupId?.trim().isEmpty ?? true ? null : groupId!.trim(),
      'classId': classId?.trim().isEmpty ?? true ? null : classId!.trim(),
      'sectionId': sectionId?.trim().isEmpty ?? true ? null : sectionId!.trim(),
      'parentMobile': parentMobile?.trim().isEmpty ?? true ? null : parentMobile!.trim(),
      'createdByUid': createdByUid?.trim(),
      'createdByName': createdByName?.trim(),
      'createdByRole': createdByRole?.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Basic scope validation.
    if (scope == NotificationScope.group && (payload['groupId'] == null)) {
      throw Exception('Select group');
    }
    if (scope == NotificationScope.classSection && (payload['classId'] == null || payload['sectionId'] == null)) {
      throw Exception('Select class and section');
    }
    if (scope == NotificationScope.parent && (payload['parentMobile'] == null)) {
      throw Exception('Enter parent mobile');
    }

    final ref = _schoolDoc(schoolId: schoolId).collection('notifications').doc();
    await ref.set(payload);
    return ref.id;
  }
}
