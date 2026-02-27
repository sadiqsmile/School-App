import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/attendance_service_enhanced.dart';
import '../../../services/attendance_analytics_service.dart';
import '../../../widgets/loading_view.dart';

/// Enhanced parent attendance view to see child's attendance
class EnhancedParentAttendanceScreen extends ConsumerStatefulWidget {
  const EnhancedParentAttendanceScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  ConsumerState<EnhancedParentAttendanceScreen> createState() =>
      _EnhancedParentAttendanceScreenState();
}

class _EnhancedParentAttendanceScreenState
    extends ConsumerState<EnhancedParentAttendanceScreen> {
  final _attendanceService = AttendanceServiceEnhanced();
  final _analyticsService = AttendanceAnalyticsService();

  DateTime _selectedMonth = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _loading = true;
  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _monthlyRecords = [];
  String? _classId;
  String? _sectionId;

  @override
  void initState() {
    super.initState();
    _loadChildInfo();
  }

  Future<void> _loadChildInfo() async {
    try {
      // Get child's class and section from Firestore
      final studentDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc('school_001')
          .collection('students')
          .doc(widget.childId)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data();
        _classId = data?['class'] as String?;
        _sectionId = data?['section'] as String?;

        if (_classId != null && _sectionId != null) {
          await _loadAttendance();
        }
      }
    } catch (e) {
      _showError('Error loading child info: $e');
    }
  }

  Future<void> _loadAttendance() async {
    if (_classId == null || _sectionId == null) return;

    setState(() => _loading = true);

    try {
      final startOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      // Load monthly attendance records
      final records = await _attendanceService
          .watchStudentMonthAttendance(
            classId: _classId!,
            sectionId: _sectionId!,
            studentId: widget.childId,
            month: _selectedMonth,
          )
          .first;

      // Load statistics
      final stats = await _analyticsService.getStudentStatistics(
        schoolId: 'school_001',
        classId: _classId!,
        sectionId: _sectionId!,
        studentId: widget.childId,
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      setState(() {
        _monthlyRecords = records;
        _statistics = stats;
      });
    } catch (e) {
      _showError('Error loading attendance: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getColorForStatus(String? status) {
    switch (status) {
      case 'P':
        return Colors.green;
      case 'A':
        return Colors.red;
      case 'H':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingView());
    }

    if (_classId == null || _sectionId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.childName}\'s Attendance')),
        body: const Center(
          child: Text('Unable to load child information'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childName}\'s Attendance'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAttendance,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child info card
              _buildChildInfoCard(),
              const SizedBox(height: 16),

              // Statistics cards
              if (_statistics != null) _buildStatisticsSection(),
              const SizedBox(height: 24),

              // Calendar view
              _buildCalendarSection(),
              const SizedBox(height: 24),

              // Monthly list view
              _buildMonthlyListSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            widget.childName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          widget.childName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Class: $_classId - $_sectionId'),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final stats = _statistics!;
    final percentage = stats['percentage'] as double;
    final present = stats['present'] as int;
    final absent = stats['absent'] as int;
    final total = stats['total'] as int;

    // Determine status color and message
    String statusMessage;
    Color statusColor;
    IconData statusIcon;

    if (percentage >= 90) {
      statusMessage = 'Excellent attendance! Keep it up! 🌟';
      statusColor = Colors.green;
      statusIcon = Icons.sentiment_very_satisfied;
    } else if (percentage >= 85) {
      statusMessage = 'Good attendance. Doing well!';
      statusColor = Colors.lightGreen;
      statusIcon = Icons.sentiment_satisfied;
    } else if (percentage >= 75) {
      statusMessage = 'Attendance needs improvement.';
      statusColor = Colors.orange;
      statusIcon = Icons.sentiment_neutral;
    } else {
      statusMessage = 'Low attendance! Please improve.';
      statusColor = Colors.red;
      statusIcon = Icons.sentiment_dissatisfied;
    }

    return Column(
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Percentage circle
                SizedBox(
                  height: 150,
                  width: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 150,
                        width: 150,
                        child: CircularProgressIndicator(
                          value: percentage / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          const Text(
                            'Attendance',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', '$total', Icons.calendar_today, Colors.blue),
                    _buildStatItem('Present', '$present', Icons.check_circle, Colors.green),
                    _buildStatItem('Absent', '$absent', Icons.cancel, Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Status message card
        Card(
          color: statusColor.withOpacity(0.1),
          child: ListTile(
            leading: Icon(statusIcon, color: statusColor, size: 32),
            title: Text(
              statusMessage,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCalendarSection() {
    // Create a map of dates to statuses
    final attendanceMap = <DateTime, String>{};
    for (final record in _monthlyRecords) {
      final date = record['date'] as DateTime;
      final status = record['status'] as String?;
      if (status != null) {
        attendanceMap[DateTime(date.year, date.month, date.day)] = status;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
              lastDay: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: const Icon(Icons.chevron_left),
                rightChevronIcon: const Icon(Icons.chevron_right),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                  _selectedMonth = focusedDay;
                });
                _loadAttendance();
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final normalizedDay = DateTime(day.year, day.month, day.day);
                  final status = attendanceMap[normalizedDay];
                  
                  if (status != null) {
                    return Container(
                      margin: const EdgeInsets.all(4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _getColorForStatus(status),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
            const Divider(),
            // Legend
            Wrap(
              spacing: 16,
              children: [
                _buildLegendItem('Present', Colors.green),
                _buildLegendItem('Absent', Colors.red),
                _buildLegendItem('Holiday', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMonthlyListSection() {
    if (_monthlyRecords.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No attendance records for this month'),
          ),
        ),
      );
    }

    // Sort by date (most recent first)
    final sortedRecords = List<Map<String, dynamic>>.from(_monthlyRecords);
    sortedRecords.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Attendance History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedRecords.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = sortedRecords[index];
              final date = record['date'] as DateTime;
              final status = record['status'] as String?;
              final dateStr = DateFormat('EEE, MMM d, yyyy').format(date);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getColorForStatus(status),
                  child: Icon(
                    status == 'P'
                        ? Icons.check
                        : status == 'A'
                            ? Icons.close
                            : Icons.wb_sunny,
                    color: Colors.white,
                  ),
                ),
                title: Text(dateStr),
                trailing: Chip(
                  label: Text(
                    status == 'P'
                        ? 'Present'
                        : status == 'A'
                            ? 'Absent'
                            : 'Holiday',
                  ),
                  backgroundColor: _getColorForStatus(status).withOpacity(0.2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
