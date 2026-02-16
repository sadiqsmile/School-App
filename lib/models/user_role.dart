enum UserRole {
  parent,
  teacher,
  admin;

  static UserRole? tryParse(String? value) {
    switch (value) {
      case 'parent':
        return UserRole.parent;
      case 'teacher':
        return UserRole.teacher;
      case 'admin':
        return UserRole.admin;
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
    }
  }
}
