import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';

/// Service for attendance analytics and statistics
class AttendanceAnalyticsService {
  AttendanceAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({
    String schoolId = AppConfig.schoolId,
  }) {
    return _firestore.collection('schools').doc(schoolId);
  }

  String dateId(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  String classSectionId({required String classId, required String sectionId}) {
    return '${classId}_$sectionId';
  }

  // ============================================================================
  // MONTHLY BAR CHART DATA
  // ============================================================================

  /// Get daily attendance data for a month (for bar chart)
  Future<List<Map<String, dynamic>>> getMonthlyChartData({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime month,
  }) async {
    final csId = classSectionId(classId: classId, sectionId: sectionId);
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('meta.date', isLessThan: Timestamp.fromDate(end))
        .orderBy('meta.date')
        .get();

    final chartData = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final meta = doc.data()['meta'] as Map<String, dynamic>?;
      if (meta != null) {
        final date = (meta['date'] as Timestamp).toDate();
        final presentCount = meta['presentCount'] as int? ?? 0;
        final absentCount = meta['absentCount'] as int? ?? 0;
        final totalStudents = meta['totalStudents'] as int? ?? 0;
        final percentage = totalStudents > 0
            ? (presentCount / totalStudents) * 100
            : 0.0;

        chartData.add({
          'date': date,
          'day': date.day,
          'presentCount': presentCount,
          'absentCount': absentCount,
          'totalStudents': totalStudents,
          'percentage': percentage,
        });
      }
    }

    return chartData;
  }

  // ============================================================================
  // DAILY TREND LINE DATA
  // ============================================================================

  /// Get attendance trend over a date range (for line chart)
  Future<List<Map<String, dynamic>>> getTrendData({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final csId = classSectionId(classId: classId, sectionId: sectionId);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('meta.date')
        .get();

    final trendData = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final meta = doc.data()['meta'] as Map<String, dynamic>?;
      if (meta != null) {
        final date = (meta['date'] as Timestamp).toDate();
        final presentCount = meta['presentCount'] as int? ?? 0;
        final totalStudents = meta['totalStudents'] as int? ?? 0;
        final percentage = totalStudents > 0
            ? (presentCount / totalStudents) * 100
            : 0.0;

        trendData.add({
          'date': date,
          'percentage': percentage,
        });
      }
    }

    return trendData;
  }

  // ============================================================================
  // STUDENT-WISE PIE CHART DATA
  // ============================================================================

  /// Get student-wise attendance distribution (for pie chart)
  Future<Map<String, dynamic>> getStudentWiseDistribution({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final csId = classSectionId(classId: classId, sectionId: sectionId);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    // Count students by attendance percentage ranges
    final studentAttendance = <String, Map<String, int>>{};

    for (final doc in snapshot.docs) {
      final studentsData = doc.data()['students'] as Map<String, dynamic>?;
      if (studentsData == null) continue;

      for (final entry in studentsData.entries) {
        final studentId = entry.key;
        final studentData = entry.value as Map<String, dynamic>;
        final status = studentData['status'] as String?;

        if (!studentAttendance.containsKey(studentId)) {
          studentAttendance[studentId] = {'present': 0, 'absent': 0};
        }

        if (status == 'P') {
          studentAttendance[studentId]!['present'] =
              (studentAttendance[studentId]!['present'] ?? 0) + 1;
        } else if (status == 'A') {
          studentAttendance[studentId]!['absent'] =
              (studentAttendance[studentId]!['absent'] ?? 0) + 1;
        }
      }
    }

    // Categorize students by percentage
    var excellent = 0; // >= 95%
    var good = 0; // 85-94%
    var average = 0; // 75-84%
    var belowAverage = 0; // 65-74%
    var poor = 0; // < 65%

    for (final attendance in studentAttendance.values) {
      final present = attendance['present'] ?? 0;
      final absent = attendance['absent'] ?? 0;
      final total = present + absent;

      if (total == 0) continue;

      final percentage = (present / total) * 100;

      if (percentage >= 95) {
        excellent++;
      } else if (percentage >= 85) {
        good++;
      } else if (percentage >= 75) {
        average++;
      } else if (percentage >= 65) {
        belowAverage++;
      } else {
        poor++;
      }
    }

    return {
      'excellent': excellent,
      'good': good,
      'average': average,
      'belowAverage': belowAverage,
      'poor': poor,
      'totalStudents': studentAttendance.length,
    };
  }

  // ============================================================================
  // OVERALL STATISTICS
  // ============================================================================

  /// Get overall attendance statistics
  Future<Map<String, dynamic>> getOverallStatistics({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final csId = classSectionId(classId: classId, sectionId: sectionId);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    var totalPresent = 0;
    var totalAbsent = 0;
    var totalDays = 0;
    var totalHolidays = 0;

    for (final doc in snapshot.docs) {
      final meta = doc.data()['meta'] as Map<String, dynamic>?;
      if (meta != null) {
        final isHoliday = meta['isHoliday'] as bool? ?? false;
        
        if (isHoliday) {
          totalHolidays++;
        } else {
          totalPresent += (meta['presentCount'] as int?) ?? 0;
          totalAbsent += (meta['absentCount'] as int?) ?? 0;
          totalDays++;
        }
      }
    }

    final totalMarked = totalPresent + totalAbsent;
    final percentage = totalMarked > 0 ? (totalPresent / totalMarked) * 100 : 0.0;

    return {
      'totalDays': totalDays,
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
      'totalHolidays': totalHolidays,
      'percentage': percentage,
    };
  }

  // ============================================================================
  // STUDENT-SPECIFIC ANALYTICS
  // ============================================================================

  /// Get individual student attendance statistics
  Future<Map<String, dynamic>> getStudentStatistics({
    required String schoolId,
    required String classId,
    required String sectionId,
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final csId = classSectionId(classId: classId, sectionId: sectionId);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    var present = 0;
    var absent = 0;
    var holidays = 0;
    var unmarked = 0;

    for (final doc in snapshot.docs) {
      final meta = doc.data()['meta'] as Map<String, dynamic>?;
      final isHoliday = meta?['isHoliday'] as bool? ?? false;

      if (isHoliday) {
        holidays++;
        continue;
      }

      final studentsData = doc.data()['students'] as Map<String, dynamic>?;
      final studentData = studentsData?[studentId] as Map<String, dynamic>?;

      if (studentData == null) {
        unmarked++;
        continue;
      }

      final status = studentData['status'] as String?;
      if (status == 'P') {
        present++;
      } else if (status == 'A') {
        absent++;
      } else {
        unmarked++;
      }
    }

    final total = present + absent;
    final percentage = total > 0 ? (present / total) * 100 : 0.0;

    return {
      'present': present,
      'absent': absent,
      'holidays': holidays,
      'unmarked': unmarked,
      'total': total,
      'percentage': percentage,
    };
  }

  // ============================================================================
  // COMPARISON ANALYTICS
  // ============================================================================

  /// Compare attendance across multiple classes
  Future<List<Map<String, dynamic>>> compareClassAttendance({
    required String schoolId,
    required List<Map<String, String>> classes, // [{classId, sectionId}]
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final comparisonData = <Map<String, dynamic>>[];

    for (final classInfo in classes) {
      final classId = classInfo['classId']!;
      final sectionId = classInfo['sectionId']!;

      final stats = await getOverallStatistics(
        schoolId: schoolId,
        classId: classId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate,
      );

      comparisonData.add({
        'classId': classId,
        'sectionId': sectionId,
        'label': '$classId - $sectionId',
        ...stats,
      });
    }

    return comparisonData;
  }

  // ============================================================================
  // ALERTS & NOTIFICATIONS DATA
  // ============================================================================

  /// Get students with low attendance (below threshold)
  Future<List<Map<String, dynamic>>> getLowAttendanceStudents({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime startDate,
    required DateTime endDate,
    double threshold = 75.0,
  }) async {
    final csId = classSectionId(classId: classId, sectionId: sectionId);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final studentAttendance = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final studentsData = doc.data()['students'] as Map<String, dynamic>?;
      if (studentsData == null) continue;

      for (final entry in studentsData.entries) {
        final studentId = entry.key;
        final studentData = entry.value as Map<String, dynamic>;
        final status = studentData['status'] as String?;
        final studentName = studentData['studentName'] as String? ?? 'Unknown';
        final rollNumber = studentData['rollNumber'] as String? ?? '';

        if (!studentAttendance.containsKey(studentId)) {
          studentAttendance[studentId] = {
            'studentId': studentId,
            'studentName': studentName,
            'rollNumber': rollNumber,
            'present': 0,
            'absent': 0,
          };
        }

        if (status == 'P') {
          studentAttendance[studentId]!['present'] =
              (studentAttendance[studentId]!['present'] as int) + 1;
        } else if (status == 'A') {
          studentAttendance[studentId]!['absent'] =
              (studentAttendance[studentId]!['absent'] as int) + 1;
        }
      }
    }

    // Filter low attendance students
    final lowAttendanceList = <Map<String, dynamic>>[];

    for (final data in studentAttendance.values) {
      final present = data['present'] as int;
      final absent = data['absent'] as int;
      final total = present + absent;

      if (total == 0) continue;

      final percentage = (present / total) * 100;

      if (percentage < threshold) {
        lowAttendanceList.add({
          ...data,
          'percentage': percentage,
          'total': total,
        });
      }
    }

    // Sort by percentage (lowest first)
    lowAttendanceList.sort((a, b) =>
        (a['percentage'] as double).compareTo(b['percentage'] as double));

    return lowAttendanceList;
  }
}
