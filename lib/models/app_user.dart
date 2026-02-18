import 'user_role.dart';

class AppUser {
  AppUser({
    required this.uid,
    required this.schoolId,
    required this.role,
    required this.displayName,
    required this.email,
    required this.phone,
    this.assignedGroups = const <String>[],
    // Student-specific fields
    this.classId,
    this.sectionId,
    this.groupId,
  });

  final String uid;
  final String schoolId;
  final UserRole role;
  final String displayName;
  final String? email;
  final String? phone;
  final List<String> assignedGroups;
  
  // Student-specific fields
  final String? classId;
  final String? sectionId;
  final String? groupId;

  factory AppUser.fromMap({
    required String uid,
    required String schoolId,
    required Map<String, Object?> map,
  }) {
    final role = UserRole.tryParse(map['role'] as String?);
    if (role == null) {
      throw StateError('Invalid or missing role for user $uid');
    }

    final groupsRaw = map['assignedGroups'] as List?;
    final groups = (groupsRaw ?? const []).whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return AppUser(
      uid: uid,
      schoolId: schoolId,
      role: role,
      displayName: (map['displayName'] as String?) ?? 'User',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      assignedGroups: groups,
      // Student-specific fields
      classId: map['classId'] as String?,
      sectionId: map['sectionId'] as String?,
      groupId: map['groupId'] as String?,
    );
  }
}
