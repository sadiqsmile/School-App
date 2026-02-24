import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/attendance_summary.dart';
import '../../../models/student_base.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_providers.dart';
import '../../../services/attendance_service_enhanced.dart';
import '../../../services/attendance_notification_service.dart';
import '../../../widgets/loading_view.dart';

/// Enhanced attendance marking screen with time restrictions and bulk operations
class EnhancedAttendanceMarkingScreen extends ConsumerStatefulWidget {
  const EnhancedAttendanceMarkingScreen({
    super.key,
    required this.classId,
    required this.sectionId,
    required this.date,
    this.yearId = '2024-2025',
  });

  final String classId;
  final String sectionId;
  final DateTime date;
  final String yearId;

  @override
  ConsumerState<EnhancedAttendanceMarkingScreen> createState() =>
      _EnhancedAttendanceMarkingScreenState();
}

class _EnhancedAttendanceMarkingScreenState
    extends ConsumerState<EnhancedAttendanceMarkingScreen> {
  final _attendanceService = AttendanceServiceEnhanced();
  final _notificationService = AttendanceNotificationService();

  Map<String, AttendanceStatus> _attendanceRecords = {};
  bool _isHoliday = false;
  String? _holidayReason;
  bool _loading = true;
  bool _saving = false;
  bool _initialized = false;
  bool _isLocked = false;
  bool _canEdit = false;
  UserRole? _userRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final user = ref.read(firebaseAuthUserProvider).value;
      if (user == null) return;

      // Check permissions
      _canEdit = await _attendanceService.canEditAttendance(
        userId: user.uid,
        schoolId: 'school_001',
        date: widget.date,
      );

      // Load existing attendance if any
      final doc = await _attendanceService
          .attendanceDocRef(
            classId: widget.classId,
            sectionId: widget.sectionId,
            date: widget.date,
          )
          .get();

      if (doc.exists) {
        final data = doc.data();
        final meta = data?['meta'] as Map<String, dynamic>?;
        final students = data?['students'] as Map<String, dynamic>?;

        if (meta != null) {
          _isLocked = meta['locked'] as bool? ?? false;
          _isHoliday = meta['isHoliday'] as bool? ?? false;
          _holidayReason = meta['holidayReason'] as String?;

          final roleString = meta['markedByRole'] as String?;
          _userRole = UserRole.tryParse(roleString);
        }

        if (students != null) {
          setState(() {
            _attendanceRecords = students.map((key, value) {
              final status = value['status'] as String?;
              return MapEntry(
                key,
                AttendanceStatus.fromString(status),
              );
            });
          });
        }
      }

      _initialized = true;
    } catch (e) {
      _showError('Error loading data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ============================================================================
  // BULK OPERATIONS
  // ============================================================================

  void _markAllPresent(List<StudentBase> students) {
    setState(() {
      _isHoliday = false;
      for (final student in students) {
        _attendanceRecords[student.id] = AttendanceStatus.present;
      }
    });
  }

  void _markAllAbsent(List<StudentBase> students) {
    setState(() {
      _isHoliday = false;
      for (final student in students) {
        _attendanceRecords[student.id] = AttendanceStatus.absent;
      }
    });
  }

  void _markAsHoliday(List<StudentBase> students) async {
    final reason = await _showHolidayDialog();
    if (reason != null) {
      setState(() {
        _isHoliday = true;
        _holidayReason = reason;
        for (final student in students) {
          _attendanceRecords[student.id] = AttendanceStatus.holiday;
        }
      });
    }
  }

  Future<String?> _showHolidayDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Holiday'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Holiday Reason',
            hintText: 'e.g., National Holiday, School Event',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SAVE ATTENDANCE
  // ============================================================================

  Future<void> _saveAttendance(List<StudentBase> students) async {
    final user = ref.read(firebaseAuthUserProvider).value;
    if (user == null) return;

    // Get user role from Firestore
    final userRole = await _getUserRole(user.uid);

    // Check time restrictions
    if (!_canEdit && userRole != UserRole.admin) {
      _showError(
        'Attendance can only be marked between 10:00 AM and 4:00 PM.\n'
        'Only admin can edit outside this window.',
      );
      return;
    }

    // Check if locked
    if (_isLocked && userRole != UserRole.admin) {
      _showError('Attendance is locked. Only admin can edit.');
      return;
    }

    setState(() => _saving = true);

    try {
      await _attendanceService.saveAttendanceEnhanced(
        classId: widget.classId,
        sectionId: widget.sectionId,
        date: widget.date,
        markedByUid: user.uid,
        markedByRole: userRole,
        students: students,
        records: _attendanceRecords,
        isHoliday: _isHoliday,
        holidayReason: _holidayReason,
        forceOverride: userRole == UserRole.admin,
      );

      // Send notifications for absent students
      if (!_isHoliday) {
        final absentStudents = <String, String>{};
        for (final student in students) {
          if (_attendanceRecords[student.id] == AttendanceStatus.absent) {
            absentStudents[student.id] = student.name;
          }
        }

        if (absentStudents.isNotEmpty) {
          await _notificationService.sendBatchAbsentNotifications(
            schoolId: 'school_001',
            absentStudents: absentStudents,
            date: widget.date,
          );
        }
      }

      if (!mounted) return;
      _showSuccess('Attendance saved successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Error saving attendance: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<UserRole> _getUserRole(String userId) async {
    // This would typically fetch from Firestore
    // For now, return from cached value or fetch again
    return _userRole ?? UserRole.teacher;
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    // Fetch students from existing service
    return StreamBuilder<List<StudentBase>>(
      stream: _attendanceService.watchStudentsForClassSection(
        classId: widget.classId,
        sectionId: widget.sectionId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingView());
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final students = snapshot.data ?? [];

        if (students.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mark Attendance')),
            body: const Center(child: Text('No students found')),
          );
        }

        // Initialize attendance records
        if (!_initialized) {
          for (final student in students) {
            _attendanceRecords.putIfAbsent(
              student.id,
              () => AttendanceStatus.present,
            );
          }
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Mark Attendance - ${widget.classId}'),
            actions: [
              if (_isLocked && _userRole == UserRole.admin)
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⚠️ Admin Override Mode',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Date and time info
              _buildDateHeader(),

              // Bulk action buttons
              _buildBulkActionsBar(students),

              // Summary header
              _buildSummaryHeader(students),

              // Student list
              Expanded(
                child: _buildStudentList(students),
              ),

              // Save button
              _buildSaveButton(students),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateHeader() {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(widget.date);
    final timeStr = DateFormat('hh:mm a').format(DateTime.now());
    final isWithinTime = _attendanceService.isWithinAttendanceTime();

    return Container(
      padding: const EdgeInsets.all(16),
      color: isWithinTime ? Colors.green.shade50 : Colors.orange.shade50,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Current Time: $timeStr', style: const TextStyle(fontSize: 12)),
                ],
              ),
              Icon(
                isWithinTime ? Icons.check_circle : Icons.warning,
                color: isWithinTime ? Colors.green : Colors.orange,
              ),
            ],
          ),
          if (!isWithinTime && _userRole != UserRole.admin)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ Outside marking hours (10 AM - 4 PM). Only admin can edit.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBulkActionsBar(List<StudentBase> students) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isHoliday ? null : () => _markAllPresent(students),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Present All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isHoliday ? null : () => _markAllAbsent(students),
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Absent All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markAsHoliday(students),
              icon: const Icon(Icons.wb_sunny, size: 18),
              label: const Text('Holiday'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(List<StudentBase> students) {
    final totalStudents = students.length;
    final presentCount = _attendanceRecords.values
        .where((s) => s == AttendanceStatus.present)
        .length;
    final absentCount = _attendanceRecords.values
        .where((s) => s == AttendanceStatus.absent)
        .length;
    final percentage = totalStudents > 0
        ? (presentCount / totalStudents) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
      ),
      child: _isHoliday
          ? Column(
              children: [
                const Icon(Icons.wb_sunny, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'HOLIDAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_holidayReason != null)
                  Text(
                    _holidayReason!,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total', '$totalStudents', Icons.people),
                _buildStatCard('Present', '$presentCount', Icons.check_circle,
                    color: Colors.green),
                _buildStatCard('Absent', '$absentCount', Icons.cancel,
                    color: Colors.red),
                _buildStatCard(
                  'Attendance',
                  '${percentage.toStringAsFixed(1)}%',
                  Icons.analytics,
                  color: percentage >= 75 ? Colors.green : Colors.orange,
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon,
      {Color color = Colors.white}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStudentList(List<StudentBase> students) {
    // Sort by roll number
    final sortedStudents = List<StudentBase>.from(students);
    sortedStudents.sort((a, b) {
      final aRoll = a.rollNumber ?? '';
      final bRoll = b.rollNumber ?? '';
      final aNum = int.tryParse(aRoll);
      final bNum = int.tryParse(bRoll);
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      return aRoll.compareTo(bRoll);
    });

    return ListView.builder(
      itemCount: sortedStudents.length,
      itemBuilder: (context, index) {
        final student = sortedStudents[index];
        final status =
            _attendanceRecords[student.id] ?? AttendanceStatus.present;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == AttendanceStatus.present
                  ? Colors.green
                  : status == AttendanceStatus.absent
                      ? Colors.red
                      : Colors.orange,
              child: Text(
                student.rollNumber ?? '?',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Roll: ${student.rollNumber ?? 'N/A'}'),
            trailing: _isHoliday
                ? const Icon(Icons.wb_sunny, color: Colors.orange)
                : Switch(
                    value: status == AttendanceStatus.present,
                    onChanged: (value) {
                      setState(() {
                        _attendanceRecords[student.id] = value
                            ? AttendanceStatus.present
                            : AttendanceStatus.absent;
                      });
                    },
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton(List<StudentBase> students) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : () => _saveAttendance(students),
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_saving ? 'Saving...' : 'Save Attendance'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
