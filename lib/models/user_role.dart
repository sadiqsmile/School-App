enum UserRole {
  parent,
  teacher,
  admin,
  student;

  static UserRole? tryParse(String? value) {
    switch (value) {
      case 'parent':
        return UserRole.parent;
      case 'teacher':
        return UserRole.teacher;
      case 'admin':
        return UserRole.admin;
      case 'student':
        return UserRole.student;
      default:
        return null;
    }
  }

  String get asString {
    switch (this) {
      case UserRole.parent:
        return 'parent';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.admin:
        return 'admin';
      case UserRole.student:
        return 'student';
    }
  }
}
