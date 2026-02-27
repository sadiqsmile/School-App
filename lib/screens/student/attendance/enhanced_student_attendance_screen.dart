import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../providers/auth_providers.dart';
import '../../../services/attendance_service_enhanced.dart';
import '../../../services/attendance_analytics_service.dart';
import '../../../widgets/loading_view.dart';

/// Enhanced student attendance view with calendar and statistics
class EnhancedStudentAttendanceScreen extends ConsumerStatefulWidget {
  const EnhancedStudentAttendanceScreen({super.key});

  @override
  ConsumerState<EnhancedStudentAttendanceScreen> createState() =>
      _EnhancedStudentAttendanceScreenState();
}

class _EnhancedStudentAttendanceScreenState
    extends ConsumerState<EnhancedStudentAttendanceScreen> {
  final _attendanceService = AttendanceServiceEnhanced();
  final _analyticsService = AttendanceAnalyticsService();

  DateTime _selectedMonth = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _loading = true;
  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _monthlyRecords = [];

  @override
  void initState() {
super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loading = true);

    try {
      final appUser = ref.read(appUserProvider).value;
      if (appUser == null ||
          appUser.classId == null ||
          appUser.sectionId == null) {
        return;
      }

      final startOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      // Load monthly attendance records
      final records = await _attendanceService
          .watchStudentMonthAttendance(
            classId: appUser.classId!,
            sectionId: appUser.sectionId!,
            studentId: appUser.uid,
            month: _selectedMonth,
          )
          .first;

      // Load statistics
      final stats = await _analyticsService.getStudentStatistics(
        schoolId: 'school_001',
        classId: appUser.classId!,
        sectionId: appUser.sectionId!,
        studentId: appUser.uid,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAttendance,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

  Widget _buildStatisticsSection() {
    final stats = _statistics!;
    final percentage = stats['percentage'] as double;
    final present = stats['present'] as int;
    final absent = stats['absent'] as int;
    final total = stats['total'] as int;

    return Card(
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 85
                            ? Colors.green
                            : percentage >= 75
                                ? Colors.orange
                                : Colors.red,
                      ),
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
                          color: percentage >= 85
                              ? Colors.green
                              : percentage >= 75
                                  ? Colors.orange
                                  : Colors.red,
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
