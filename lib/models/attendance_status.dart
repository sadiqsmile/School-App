enum AttendanceStatus {
  present,
  absent,
  leave;

  String get asString {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.leave:
        return 'leave';
    }
  }

  static AttendanceStatus fromString(String? value) {
    switch (value) {
      case 'present':
        return AttendanceStatus.present;
      case 'leave':
        return AttendanceStatus.leave;
      case 'absent':
      default:
        return AttendanceStatus.absent;
    }
  }
}
