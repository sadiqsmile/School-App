import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../models/attendance_summary.dart';
import '../models/student_base.dart';
import '../models/user_role.dart';

/// Enhanced attendance service with time restrictions, locking, and analytics
class AttendanceServiceEnhanced {
  AttendanceServiceEnhanced({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ============================================================================
  // TIME RESTRICTION LOGIC
  // ============================================================================

  /// Check if current time is within attendance marking window (10 AM - 4 PM)
  bool isWithinAttendanceTime() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 10, 0);
    final end = DateTime(now.year, now.month, now.day, 16, 0);
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Check if user can edit attendance based on time and role
  Future<bool> canEditAttendance({
    required String userId,
    required String schoolId,
    DateTime? date,
  }) async {
    // Get user role
    final userRole = await _getUserRole(userId, schoolId);
    
    // Admin can always edit
    if (userRole == UserRole.admin) {
      return true;
    }

    // Check if it's today and within time window
    final targetDate = date ?? DateTime.now();
    final isToday = _isSameDay(targetDate, DateTime.now());
    
    if (!isToday) {
      // Can only edit past dates if admin
      return false;
    }

    // Teachers can edit only within time window
    return isWithinAttendanceTime();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get user role from Firestore
  Future<UserRole> _getUserRole(String userId, String schoolId) async {
    try {
      final userDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return UserRole.teacher; // Default fallback
      }

      final roleString = userDoc.data()?['role'] as String?;
      return UserRole.tryParse(roleString) ?? UserRole.teacher;
    } catch (e) {
      return UserRole.teacher; // Fallback on error
    }
  }

  // ============================================================================
  // DOCUMENT REFERENCES
  // ============================================================================

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

  String monthId(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  String classSectionId({required String classId, required String sectionId}) {
    return '${classId}_$sectionId';
  }

  // New structure: schools/{schoolId}/attendance/{class_section}/{date}
  DocumentReference<Map<String, dynamic>> attendanceDocRef({
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String sectionId,
    required DateTime date,
  }) {
    final csId = classSectionId(classId: classId, sectionId: sectionId);
    return _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .doc(dateId(date));
  }

  // Monthly summary: schools/{schoolId}/attendance_summary/{class_section}/{month}
  DocumentReference<Map<String, dynamic>> monthlySummaryDocRef({
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String sectionId,
    required DateTime month,
  }) {
    final csId = classSectionId(classId: classId, sectionId: sectionId);
    return _schoolDoc(schoolId: schoolId)
        .collection('attendance_summary')
        .doc(csId)
        .collection('months')
        .doc(monthId(month));
  }

  // ============================================================================
  // SAVE ATTENDANCE WITH ENHANCED FEATURES
  // ============================================================================

  /// Save attendance for a class with locking, time validation, and notifications
  Future<void> saveAttendanceEnhanced({
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String sectionId,
    required DateTime date,
    required String markedByUid,
    required UserRole markedByRole,
    required List<StudentBase> students,
    required Map<String, AttendanceStatus> records,
    required bool isHoliday,
    String? holidayReason,
    bool forceOverride = false,
  }) async {
    // Validate time restriction
    if (!forceOverride) {
      final canEdit = await canEditAttendance(
        userId: markedByUid,
        schoolId: schoolId,
        date: date,
      );

      if (!canEdit) {
        throw AttendanceTimeRestrictionException(
          'Attendance can only be marked between 10:00 AM and 4:00 PM. '
          'Only admin can edit outside this window.',
        );
      }
    }

    final normalized = DateTime(date.year, date.month, date.day);
    final attendanceRef = attendanceDocRef(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
      date: normalized,
    );

    // Check if already locked
    final existingDoc = await attendanceRef.get();
    if (existingDoc.exists) {
      final isLocked = existingDoc.data()?['locked'] as bool? ?? false;
      if (isLocked && markedByRole != UserRole.admin) {
        throw AttendanceLockedException(
          'Attendance is locked. Only admin can edit.',
        );
      }
    }

    // Count statistics
    var presentCount = 0;
    var absentCount = 0;
    var holidayCount = 0;

    final studentRecords = <String, Map<String, dynamic>>{};
    final absentStudentIds = <String>[];

    for (final student in students) {
      final status = records[student.id] ?? AttendanceStatus.present;
      final statusValue = status.toFirestoreValue();

      studentRecords[student.id] = {
        'status': statusValue,
        'studentName': student.fullName,
        'rollNumber': student.admissionNo ?? '',
      };

      if (status == AttendanceStatus.present) {
        presentCount++;
      } else if (status == AttendanceStatus.absent) {
        absentCount++;
        absentStudentIds.add(student.id);
      } else if (status == AttendanceStatus.holiday) {
        holidayCount++;
      }
    }

    // Auto-lock after 4 PM
    final now = DateTime.now();
    final shouldLock = now.hour >= 16 && markedByRole != UserRole.admin;

    // Prepare metadata
    final metaData = AttendanceDayMeta(
      dateId: dateId(normalized),
      date: normalized,
      classId: classId,
      sectionId: sectionId,
      markedBy: markedByUid,
      markedByRole: markedByRole.asString,
      timestamp: now,
      locked: shouldLock,
      isHoliday: isHoliday,
      totalStudents: students.length,
      presentCount: isHoliday ? students.length : presentCount,
      absentCount: isHoliday ? 0 : absentCount,
      holidayReason: isHoliday ? holidayReason : null,
    );

    // Save to Firestore
    await attendanceRef.set({
      'meta': metaData.toMap(),
      'students': studentRecords,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update monthly summaries for all students
    await _updateMonthlySummaries(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
      month: normalized,
      students: students,
    );

    // Check for 3 consecutive absents and send notifications
    for (final studentId in absentStudentIds) {
      final consecutive = await _getConsecutiveAbsents(
        schoolId: schoolId,
        classId: classId,
        sectionId: sectionId,
        studentId: studentId,
        endDate: normalized,
      );

      if (consecutive >= 3) {
        // Trigger alert notification (will be handled by notification service)
        await _triggerConsecutiveAbsentAlert(
          schoolId: schoolId,
          studentId: studentId,
          consecutiveDays: consecutive,
        );
      }
    }
  }

  // ============================================================================
  // MONTHLY SUMMARY CALCULATION
  // ============================================================================

  /// Update monthly attendance summary for all students
  Future<void> _updateMonthlySummaries({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime month,
    required List<StudentBase> students,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final csId = classSectionId(classId: classId, sectionId: sectionId);
    final daysCol = _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days');

    // Get all attendance records for the month
    final snapshot = await daysCol
        .where('meta.date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('meta.date', isLessThan: Timestamp.fromDate(endOfMonth))
        .get();

    // Calculate summary for each student
    for (final student in students) {
      var totalPresent = 0;
      var totalAbsent = 0;
      var totalHolidays = 0;

      for (final doc in snapshot.docs) {
        final students = doc.data()['students'] as Map<String, dynamic>?;
        if (students == null) continue;

        final studentData = students[student.id] as Map<String, dynamic>?;
        if (studentData == null) continue;

        final status = studentData['status'] as String?;
        if (status == 'P') totalPresent++;
        if (status == 'A') totalAbsent++;
        if (status == 'H') totalHolidays++;
      }

      final totalDays = totalPresent + totalAbsent;
      final percentage =
          totalDays > 0 ? (totalPresent / totalDays) * 100 : 100.0;

      // Get consecutive absents
      final consecutive = await _getConsecutiveAbsents(
        schoolId: schoolId,
        classId: classId,
        sectionId: sectionId,
        studentId: student.id,
        endDate: DateTime.now(),
      );

      final summary = AttendanceSummary(
        studentId: student.id,
        classId: classId,
        sectionId: sectionId,
        month: month.month,
        year: month.year,
        totalPresent: totalPresent,
        totalAbsent: totalAbsent,
        totalHolidays: totalHolidays,
        percentage: percentage,
        consecutiveAbsents: consecutive,
      );

      // Save summary
      final summaryRef = monthlySummaryDocRef(
        schoolId: schoolId,
        classId: classId,
        sectionId: sectionId,
        month: month,
      );

      await summaryRef.set(
        {
          'students': {
            student.id: summary.toMap(),
          },
        },
        SetOptions(merge: true),
      );
    }
  }

  // ============================================================================
  // CONSECUTIVE ABSENTS DETECTION
  // ============================================================================

  /// Get number of consecutive absent days for a student
  Future<int> _getConsecutiveAbsents({
    required String schoolId,
    required String classId,
    required String sectionId,
    required String studentId,
    required DateTime endDate,
  }) async {
    var count = 0;
    var checkDate = endDate;

    for (var i = 0; i < 10; i++) {
      // Check last 10 days max
      final docRef = attendanceDocRef(
        schoolId: schoolId,
        classId: classId,
        sectionId: sectionId,
        date: checkDate,
      );

      final doc = await docRef.get();
      if (!doc.exists) break;

      final students = doc.data()?['students'] as Map<String, dynamic>?;
      final studentData = students?[studentId] as Map<String, dynamic>?;
      final status = studentData?['status'] as String?;

      if (status == 'A') {
        count++;
      } else {
        break; // Chain broken
      }

      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return count;
  }

  /// Trigger alert for 3+ consecutive absents
  Future<void> _triggerConsecutiveAbsentAlert({
    required String schoolId,
    required String studentId,
    required int consecutiveDays,
  }) async {
    // Store alert in Firestore for admin/teacher dashboard
    await _schoolDoc(schoolId: schoolId)
        .collection('attendance_alerts')
        .add({
      'studentId': studentId,
      'consecutiveDays': consecutiveDays,
      'createdAt': FieldValue.serverTimestamp(),
      'acknowledged': false,
    });
  }

  // ============================================================================
  // LOCK/UNLOCK ATTENDANCE
  // ============================================================================

  /// Lock attendance for a specific date (auto after 4 PM)
  Future<void> lockAttendance({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime date,
  }) async {
    final ref = attendanceDocRef(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
      date: date,
    );

    await ref.update({
      'meta.locked': true,
      'meta.lockedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unlock attendance (admin only)
  Future<void> unlockAttendance({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime date,
  }) async {
    final ref = attendanceDocRef(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
      date: date,
    );

    await ref.update({
      'meta.locked': false,
      'meta.unlockedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================================
  // STREAM QUERIES
  // ============================================================================

  /// Watch attendance for a specific date
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchAttendanceDay({
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String sectionId,
    required DateTime date,
  }) {
    return attendanceDocRef(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
      date: date,
    ).snapshots();
  }

  /// Watch monthly summary for a class/section
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMonthlySummary({
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String sectionId,
    required DateTime month,
  }) {
    return monthlySummaryDocRef(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
      month: month,
    ).snapshots();
  }

  /// Watch student attendance for a month
  Stream<List<Map<String, dynamic>>> watchStudentMonthAttendance({
    String schoolId = AppConfig.schoolId,
    required String classId,
    required String sectionId,
    required String studentId,
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final csId = classSectionId(classId: classId, sectionId: sectionId);
    
    return _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('meta.date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      final records = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final meta = doc.data()['meta'] as Map<String, dynamic>?;
        final students = doc.data()['students'] as Map<String, dynamic>?;
        final studentData = students?[studentId] as Map<String, dynamic>?;
        
        if (meta != null && studentData != null) {
          records.add({
            'date': (meta['date'] as Timestamp).toDate(),
            'status': studentData['status'],
            'dateId': meta['dateId'],
          });
        }
      }
      
      records.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      return records;
    });
  }

  /// Get attendance alerts (3+ consecutive absents)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAttendanceAlerts({
    String schoolId = AppConfig.schoolId,
    bool onlyUnacknowledged = true,
  }) {
    var query = _schoolDoc(schoolId: schoolId)
        .collection('attendance_alerts')
        .orderBy('createdAt', descending: true)
        .limit(50);

    if (onlyUnacknowledged) {
      query = query.where('acknowledged', isEqualTo: false) as Query<Map<String, dynamic>>;
    }

    return query.snapshots();
  }

  /// Acknowledge an attendance alert
  Future<void> acknowledgeAlert({
    required String schoolId,
    required String alertId,
  }) async {
    await _schoolDoc(schoolId: schoolId)
        .collection('attendance_alerts')
        .doc(alertId)
        .update({
      'acknowledged': true,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================================
  // ANALYTICS & STATISTICS
  // ============================================================================

  /// Get class attendance statistics for a date range
  Future<Map<String, dynamic>> getClassStatistics({
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

    for (final doc in snapshot.docs) {
      final meta = doc.data()['meta'] as Map<String, dynamic>?;
      if (meta != null) {
        totalPresent += (meta['presentCount'] as int?) ?? 0;
        totalAbsent += (meta['absentCount'] as int?) ?? 0;
        totalDays++;
      }
    }

    final totalMarked = totalPresent + totalAbsent;
    final percentage = totalMarked > 0 ? (totalPresent / totalMarked) * 100 : 0.0;

    return {
      'totalDays': totalDays,
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
      'percentage': percentage,
    };
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class AttendanceTimeRestrictionException implements Exception {
  AttendanceTimeRestrictionException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceLockedException implements Exception {
  AttendanceLockedException(this.message);
  final String message;

  @override
  String toString() => message;
}
