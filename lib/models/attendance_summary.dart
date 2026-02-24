import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for monthly attendance summary per student
class AttendanceSummary {
  AttendanceSummary({
    required this.studentId,
    required this.classId,
    required this.sectionId,
    required this.month,
    required this.year,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalHolidays,
    required this.percentage,
    required this.consecutiveAbsents,
    this.lastUpdated,
  });

  final String studentId;
  final String classId;
  final String sectionId;
  final int month;
  final int year;
  final int totalPresent;
  final int totalAbsent;
  final int totalHolidays;
  final double percentage;
  final int consecutiveAbsents;
  final DateTime? lastUpdated;

  factory AttendanceSummary.fromMap(String docId, Map<String, dynamic> map) {
    return AttendanceSummary(
      studentId: map['studentId'] as String? ?? '',
      classId: map['classId'] as String? ?? '',
      sectionId: map['sectionId'] as String? ?? '',
      month: map['month'] as int? ?? 1,
      year: map['year'] as int? ?? DateTime.now().year,
      totalPresent: map['totalPresent'] as int? ?? 0,
      totalAbsent: map['totalAbsent'] as int? ?? 0,
      totalHolidays: map['totalHolidays'] as int? ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      consecutiveAbsents: map['consecutiveAbsents'] as int? ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'classId': classId,
      'sectionId': sectionId,
      'month': month,
      'year': year,
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
      'totalHolidays': totalHolidays,
      'percentage': percentage,
      'consecutiveAbsents': consecutiveAbsents,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

/// Model for daily attendance metadata
class AttendanceDayMeta {
  AttendanceDayMeta({
    required this.dateId,
    required this.date,
    required this.classId,
    required this.sectionId,
    required this.markedBy,
    required this.markedByRole,
    required this.timestamp,
    required this.locked,
    required this.isHoliday,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    this.holidayReason,
  });

  final String dateId;
  final DateTime date;
  final String classId;
  final String sectionId;
  final String markedBy;
  final String markedByRole;
  final DateTime timestamp;
  final bool locked;
  final bool isHoliday;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final String? holidayReason;

  double get percentage {
    if (totalStudents == 0) return 0.0;
    return (presentCount / totalStudents) * 100;
  }

  factory AttendanceDayMeta.fromMap(Map<String, dynamic> map) {
    return AttendanceDayMeta(
      dateId: map['dateId'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      classId: map['class'] as String? ?? map['classId'] as String? ?? '',
      sectionId: map['section'] as String? ?? map['sectionId'] as String? ?? '',
      markedBy: map['markedByUid'] as String? ?? map['markedBy'] as String? ?? '',
      markedByRole: map['markedByRole'] as String? ?? 'teacher',
      timestamp: (map['markedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      locked: map['locked'] as bool? ?? false,
      isHoliday: map['isHoliday'] as bool? ?? false,
      totalStudents: map['totalStudents'] as int? ?? 0,
      presentCount: map['presentCount'] as int? ?? 0,
      absentCount: map['absentCount'] as int? ?? 0,
      holidayReason: map['holidayReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateId': dateId,
      'date': Timestamp.fromDate(date),
      'class': classId,
      'section': sectionId,
      'markedByUid': markedBy,
      'markedByRole': markedByRole,
      'markedAt': Timestamp.fromDate(timestamp),
      'locked': locked,
      'isHoliday': isHoliday,
      'totalStudents': totalStudents,
      'presentCount': presentCount,
      'absentCount': absentCount,
      if (holidayReason != null) 'holidayReason': holidayReason,
    };
  }
}

/// Status for individual student attendance
enum AttendanceStatus {
  present,
  absent,
  holiday;

  static AttendanceStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'P':
      case 'PRESENT':
        return AttendanceStatus.present;
      case 'A':
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'H':
      case 'HOLIDAY':
        return AttendanceStatus.holiday;
      default:
        return AttendanceStatus.present;
    }
  }

  String toFirestoreValue() {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.holiday:
        return 'H';
    }
  }

  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.holiday:
        return 'Holiday';
    }
  }
}
