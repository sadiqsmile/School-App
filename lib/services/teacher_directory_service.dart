import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class TeacherDirectoryEntry {
  TeacherDirectoryEntry({
    required this.uid,
    required this.displayName,
    required this.phone,
    required this.subjects,
    required this.assignedGroups,
    required this.assignedClasses,
    required this.isActive,
  });

  final String uid;
  final String displayName;
  final String phone; // 10 digits (India mobile)
  final List<String> subjects;
  final List<String> assignedGroups;
  final List<String> assignedClasses; // optional, may be empty
  final bool isActive;

  static TeacherDirectoryEntry fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    List<String> listOfStrings(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw.map((e) => e?.toString() ?? '').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }

    final displayName = (data['displayName'] ?? '').toString().trim();
    final phone = (data['phone'] ?? '').toString().trim();

    return TeacherDirectoryEntry(
      uid: doc.id,
      displayName: displayName.isEmpty ? 'Teacher' : displayName,
      phone: phone,
      subjects: listOfStrings(data['subjects']),
      assignedGroups: listOfStrings(data['assignedGroups']),
      assignedClasses: listOfStrings(data['assignedClasses']),
      isActive: (data['isActive'] ?? false) == true,
    );
  }
}

class TeacherDirectoryService {
  TeacherDirectoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _users({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId).collection('users');
  }

  /// Streams active teachers matching a given student group.
  ///
  /// Firestore constraints reminder:
  /// - You can only have 1 `arrayContains` in a query.
  /// - So we query by group (assignedGroups) and filter by subject/class client-side.
  Stream<List<TeacherDirectoryEntry>> watchActiveTeachersForGroup({
    String schoolId = AppConfig.schoolId,
    required String groupId,
  }) {
    final query = _users(schoolId: schoolId)
        .where('role', isEqualTo: 'teacher')
        .where('isActive', isEqualTo: true)
        .where('assignedGroups', arrayContains: groupId);

    return query.snapshots().map((snap) {
      final items = snap.docs.map(TeacherDirectoryEntry.fromDoc).toList();
      items.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      return items;
    });
  }
}
