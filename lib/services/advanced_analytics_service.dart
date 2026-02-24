import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../models/analytics_filter.dart';

/// Advanced analytics service for comprehensive attendance analytics
class AdvancedAnalyticsService {
  AdvancedAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({
    String schoolId = AppConfig.schoolId,
  }) {
    return _firestore.collection('schools').doc(schoolId);
  }

  String classSectionId({required String classId, required String sectionId}) {
    return '${classId}_$sectionId';
  }

  // ============================================================================
  // COMPREHENSIVE METRICS
  // ============================================================================

  /// Get all analytics metrics for dashboard
  Future<AnalyticsMetrics> getComprehensiveMetrics({
    required String schoolId,
    required AnalyticsFilter filter,
  }) async {
    if (!filter.hasClassFilter) {
      throw Exception('Class and section filters are required');
    }

    final csId = classSectionId(
      classId: filter.classId!,
      sectionId: filter.sectionId!,
    );

    final startDate = filter.startDate ?? DateTime(filter.month.year, filter.month.month, 1);
    final endDate = filter.endDate ?? DateTime(filter.month.year, filter.month.month + 1, 0);

    // Get all attendance records for the period
    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    if (snapshot.docs.isEmpty) {
      return AnalyticsMetrics(
        totalStudents: 0,
        averageAttendance: 0.0,
        totalPresent: 0,
        totalAbsent: 0,
        consecutiveAbsentCount: 0,
      );
    }

    // Calculate student-wise statistics
    final studentStats = <String, Map<String, dynamic>>{};
    var totalPresent = 0;
    var totalAbsent = 0;
    var totalAttendancePercent = 0.0;
    var daysCount = 0;

    for (final doc in snapshot.docs) {
      final meta = doc.data()['meta'] as Map<String, dynamic>?;
      final students = doc.data()['students'] as Map<String, dynamic>?;
      
      if (meta == null || students == null) continue;
      
      final isHoliday = meta['isHoliday'] as bool? ?? false;
      if (isHoliday) continue;

      daysCount++;
      totalPresent += (meta['presentCount'] as int?) ?? 0;
      totalAbsent += (meta['absentCount'] as int?) ?? 0;
      
      final totalStudents = meta['totalStudents'] as int? ?? 0;
      if (totalStudents > 0) {
        totalAttendancePercent += ((meta['presentCount'] as int? ?? 0) / totalStudents) * 100;
      }

      // Process each student
      for (final entry in students.entries) {
        final studentId = entry.key;
        final studentData = entry.value as Map<String, dynamic>;
        final status = studentData['status'] as String?;
        
        if (!studentStats.containsKey(studentId)) {
          studentStats[studentId] = {
            'name': studentData['studentName'] ?? 'Unknown',
            'rollNumber': studentData['rollNumber'] ?? '',
            'present': 0,
            'absent': 0,
            'lastStatus': null,
            'consecutiveDays': 0,
          };
        }

        if (status == 'P') {
          studentStats[studentId]!['present'] = (studentStats[studentId]!['present'] as int) + 1;
          studentStats[studentId]!['consecutiveDays'] = 0;
        } else if (status == 'A') {
          studentStats[studentId]!['absent'] = (studentStats[studentId]!['absent'] as int) + 1;
          studentStats[studentId]!['consecutiveDays'] = (studentStats[studentId]!['consecutiveDays'] as int) + 1;
        }
      }
    }

    // Find lowest and highest attendance students
    StudentAttendanceRecord? lowest;
    StudentAttendanceRecord? highest;
    var consecutiveAbsentCount = 0;

    for (final entry in studentStats.entries) {
      final stats = entry.value;
      final present = stats['present'] as int;
      final absent = stats['absent'] as int;
      final total = present + absent;
      final consecutive = stats['consecutiveDays'] as int;
      
      if (total == 0) continue;
      
      final percentage = (present / total) * 100;
      
      final record = StudentAttendanceRecord(
        studentId: entry.key,
        studentName: stats['name'] as String,
        rollNumber: stats['rollNumber'] as String,
        present: present,
        absent: absent,
        percentage: percentage,
        consecutiveDays: consecutive,
      );

      if (consecutive >= 3) {
        consecutiveAbsentCount++;
      }

      if (lowest == null || percentage < lowest.percentage) {
        lowest = record;
      }
      if (highest == null || percentage > highest.percentage) {
        highest = record;
      }
    }

    final avgAttendance = daysCount > 0 ? totalAttendancePercent / daysCount : 0.0;

    return AnalyticsMetrics(
      totalStudents: studentStats.length,
      averageAttendance: avgAttendance,
      totalPresent: totalPresent,
      totalAbsent: totalAbsent,
      consecutiveAbsentCount: consecutiveAbsentCount,
      lowestAttendanceStudent: lowest,
      highestAttendanceStudent: highest,
    );
  }

  // ============================================================================
  // MONTHLY BAR CHART DATA
  // ============================================================================

  Future<List<ChartDataPoint>> getMonthlyBarChartData({
    required String schoolId,
    required AnalyticsFilter filter,
  }) async {
    if (!filter.hasClassFilter) return [];

    final csId = classSectionId(
      classId: filter.classId!,
      sectionId: filter.sectionId!,
    );

    final startDate = DateTime(filter.month.year, filter.month.month, 1);
    final endDate = DateTime(filter.month.year, filter.month.month + 1, 0);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('meta.date')
        .get();

    final chartData = <ChartDataPoint>[];

    for (final doc in snapshot.docs) {
      final meta = doc.data()['meta'] as Map<String, dynamic>?;
      if (meta == null) continue;

      final date = (meta['date'] as Timestamp).toDate();
      final isHoliday = meta['isHoliday'] as bool? ?? false;
      
      if (isHoliday) continue;

      final presentCount = meta['presentCount'] as int? ?? 0;
      final totalStudents = meta['totalStudents'] as int? ?? 0;
      final percentage = totalStudents > 0 ? (presentCount / totalStudents) * 100 : 0.0;

      chartData.add(ChartDataPoint(
        label: '${date.day}',
        value: percentage,
        color: percentage >= 85 ? 'green' : percentage >= 75 ? 'orange' : 'red',
        extraData: {
          'date': date,
          'present': presentCount,
          'total': totalStudents,
        },
      ));
    }

    return chartData;
  }

  // ============================================================================
  // STUDENT-WISE PIE CHART DATA
  // ============================================================================

  Future<Map<String, double>> getAttendancePieChartData({
    required String schoolId,
    required AnalyticsFilter filter,
  }) async {
    if (!filter.hasClassFilter) return {};

    final csId = classSectionId(
      classId: filter.classId!,
      sectionId: filter.sectionId!,
    );

    final startDate = filter.startDate ?? DateTime(filter.month.year, filter.month.month, 1);
    final endDate = filter.endDate ?? DateTime(filter.month.year, filter.month.month + 1, 0);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    var totalPresent = 0;
    var totalAbsent = 0;
    var totalHoliday = 0;

    for (final doc in snapshot.docs) {
      final meta = doc.data()['meta'] as Map<String, dynamic>?;
      if (meta == null) continue;

      final isHoliday = meta['isHoliday'] as bool? ?? false;
      
      if (isHoliday) {
        totalHoliday += meta['totalStudents'] as int? ?? 0;
      } else {
        totalPresent += meta['presentCount'] as int? ?? 0;
        totalAbsent += meta['absentCount'] as int? ?? 0;
      }
    }

    return {
      'Present': totalPresent.toDouble(),
      'Absent': totalAbsent.toDouble(),
      'Holiday': totalHoliday.toDouble(),
    };
  }

  // ============================================================================
  // TOP 5 LOWEST ATTENDANCE STUDENTS
  // ============================================================================

  Future<List<StudentAttendanceRecord>> getLowestAttendanceStudents({
    required String schoolId,
    required AnalyticsFilter filter,
    int limit = 5,
  }) async {
    if (!filter.hasClassFilter) return [];

    final csId = classSectionId(
      classId: filter.classId!,
      sectionId: filter.sectionId!,
    );

    final startDate = filter.startDate ?? DateTime(filter.month.year, filter.month.month, 1);
    final endDate = filter.endDate ?? DateTime(filter.month.year, filter.month.month + 1, 0);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final studentStats = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final students = doc.data()['students'] as Map<String, dynamic>?;
      if (students == null) continue;

      for (final entry in students.entries) {
        final studentId = entry.key;
        final studentData = entry.value as Map<String, dynamic>;
        final status = studentData['status'] as String?;

        if (!studentStats.containsKey(studentId)) {
          studentStats[studentId] = {
            'name': studentData['studentName'] ?? 'Unknown',
            'rollNumber': studentData['rollNumber'] ?? '',
            'present': 0,
            'absent': 0,
          };
        }

        if (status == 'P') {
          studentStats[studentId]!['present'] = (studentStats[studentId]!['present'] as int) + 1;
        } else if (status == 'A') {
          studentStats[studentId]!['absent'] = (studentStats[studentId]!['absent'] as int) + 1;
        }
      }
    }

    final records = <StudentAttendanceRecord>[];
    for (final entry in studentStats.entries) {
      final stats = entry.value;
      final present = stats['present'] as int;
      final absent = stats['absent'] as int;
      final total = present + absent;
      
      if (total == 0) continue;
      
      records.add(StudentAttendanceRecord(
        studentId: entry.key,
        studentName: stats['name'] as String,
        rollNumber: stats['rollNumber'] as String,
        present: present,
        absent: absent,
        percentage: (present / total) * 100,
      ));
    }

    records.sort((a, b) => a.percentage.compareTo(b.percentage));
    return records.take(limit).toList();
  }

  // ============================================================================
  // CLASS COMPARISON (ADMIN ONLY)
  // ============================================================================

  Future<List<ChartDataPoint>> getClassComparisonData({
    required String schoolId,
    required List<Map<String, String>> classes,
    required DateTime month,
  }) async {
    final chartData = <ChartDataPoint>[];

    for (final classInfo in classes) {
      final classId = classInfo['classId']!;
      final sectionId = classInfo['sectionId']!;
      final csId = classSectionId(classId: classId, sectionId: sectionId);

      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      final snapshot = await _schoolDoc(schoolId: schoolId)
          .collection('attendance')
          .doc(csId)
          .collection('days')
          .where('meta.date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      var totalPercent = 0.0;
      var count = 0;

      for (final doc in snapshot.docs) {
        final meta = doc.data()['meta'] as Map<String, dynamic>?;
        if (meta == null) continue;

        final isHoliday = meta['isHoliday'] as bool? ?? false;
        if (isHoliday) continue;

        final presentCount = meta['presentCount'] as int? ?? 0;
        final totalStudents = meta['totalStudents'] as int? ?? 0;
        
        if (totalStudents > 0) {
          totalPercent += (presentCount / totalStudents) * 100;
          count++;
        }
      }

      final avgPercent = count > 0 ? totalPercent / count : 0.0;

      chartData.add(ChartDataPoint(
        label: '$classId-$sectionId',
        value: avgPercent,
        extraData: {
          'classId': classId,
          'sectionId': sectionId,
        },
      ));
    }

    return chartData;
  }

  // ============================================================================
  // CONSECUTIVE ABSENT STUDENTS
  // ============================================================================

  Future<List<StudentAttendanceRecord>> getConsecutiveAbsentStudents({
    required String schoolId,
    required String classId,
    required String sectionId,
    int threshold = 3,
  }) async {
    final csId = classSectionId(classId: classId, sectionId: sectionId);
    
    // Get last 10 days
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 10));

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('meta.date', descending: true)
        .get();

    final studentConsecutive = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final students = doc.data()['students'] as Map<String, dynamic>?;
      if (students == null) continue;

      for (final entry in students.entries) {
        final studentId = entry.key;
        final studentData = entry.value as Map<String, dynamic>;
        final status = studentData['status'] as String?;

        if (!studentConsecutive.containsKey(studentId)) {
          studentConsecutive[studentId] = {
            'name': studentData['studentName'] ?? 'Unknown',
            'rollNumber': studentData['rollNumber'] ?? '',
            'consecutive': 0,
            'broken': false,
          };
        }

        if (studentConsecutive[studentId]!['broken'] == true) continue;

        if (status == 'A') {
          studentConsecutive[studentId]!['consecutive'] = 
              (studentConsecutive[studentId]!['consecutive'] as int) + 1;
        } else {
          studentConsecutive[studentId]!['broken'] = true;
        }
      }
    }

    final records = <StudentAttendanceRecord>[];
    for (final entry in studentConsecutive.entries) {
      final stats = entry.value;
      final consecutive = stats['consecutive'] as int;
      
      if (consecutive >= threshold) {
        records.add(StudentAttendanceRecord(
          studentId: entry.key,
          studentName: stats['name'] as String,
          rollNumber: stats['rollNumber'] as String,
          present: 0,
          absent: consecutive,
          percentage: 0.0,
          consecutiveDays: consecutive,
        ));
      }
    }

    records.sort((a, b) => b.consecutiveDays.compareTo(a.consecutiveDays));
    return records;
  }
}
