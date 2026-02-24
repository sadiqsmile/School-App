/// Filter model for attendance analytics dashboard
class AnalyticsFilter {
  AnalyticsFilter({
    required this.academicYear,
    required this.month,
    this.classId,
    this.sectionId,
    this.startDate,
    this.endDate,
  });

  final String academicYear;
  final DateTime month;
  final String? classId;
  final String? sectionId;
  final DateTime? startDate;
  final DateTime? endDate;

  AnalyticsFilter copyWith({
    String? academicYear,
    DateTime? month,
    String? classId,
    String? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return AnalyticsFilter(
      academicYear: academicYear ?? this.academicYear,
      month: month ?? this.month,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  bool get hasClassFilter => classId != null && sectionId != null;
  bool get hasDateRangeFilter => startDate != null && endDate != null;
}

/// Analytics metrics model
class AnalyticsMetrics {
  AnalyticsMetrics({
    required this.totalStudents,
    required this.averageAttendance,
    required this.totalPresent,
    required this.totalAbsent,
    required this.consecutiveAbsentCount,
    this.lowestAttendanceStudent,
    this.highestAttendanceStudent,
  });

  final int totalStudents;
  final double averageAttendance;
  final int totalPresent;
  final int totalAbsent;
  final int consecutiveAbsentCount;
  final StudentAttendanceRecord? lowestAttendanceStudent;
  final StudentAttendanceRecord? highestAttendanceStudent;
}

/// Student attendance record for analytics
class StudentAttendanceRecord {
  StudentAttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.present,
    required this.absent,
    required this.percentage,
    this.consecutiveDays = 0,
  });

  final String studentId;
  final String studentName;
  final String rollNumber;
  final int present;
  final int absent;
  final double percentage;
  final int consecutiveDays;
}

/// Chart data point
class ChartDataPoint {
  ChartDataPoint({
    required this.label,
    required this.value,
    this.color,
    this.extraData,
  });

  final String label;
  final double value;
  final String? color;
  final Map<String, dynamic>? extraData;
}
