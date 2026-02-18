import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../models/attendance_entry.dart';
import '../../../models/attendance_pa_entry.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.yearId,
    required this.studentId,
    required this.studentName,
  });

  final String yearId;
  final String studentId;
  final String studentName;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final monthKey = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final attendanceStream = ref
        .read(attendanceServiceProvider)
        .watchStudentAttendanceV3ForMonth(
          yearId: widget.yearId,
          studentId: widget.studentId,
          month: monthKey,
        )
        .map((items) {
          return items
              .map((AttendancePAEntry e) {
                final status = switch (e.status) {
                  'P' => 'present',
                  'A' => 'absent',
                  _ => 'unmarked',
                };
                return AttendanceEntry(date: e.date, status: status);
              })
              .toList(growable: false);
        });

    return Scaffold(
      appBar: AppBar(title: Text('Attendance • ${widget.studentName}')),
      body: StreamBuilder<List<AttendanceEntry>>(
        stream: attendanceStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: LoadingView(message: 'Loading attendance…'),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final entries = snapshot.data ?? const [];
          final byDay = <DateTime, AttendanceEntry>{
            for (final e in entries)
              DateTime(e.date.year, e.date.month, e.date.day): e,
          };

          final presentCount = entries.where((e) => e.isPresent).length;
          final absentCount = entries.where((e) => e.isAbsent).length;
          final marked = presentCount + absentCount;
          final percent = marked == 0 ? 0.0 : (presentCount / marked) * 100.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(monthKey),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Present: $presentCount'),
                      Text('Absent: $absentCount'),
                      const SizedBox(height: 8),
                      Text('Attendance: ${percent.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) {
                      if (_selectedDay == null) return false;
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final key = DateTime(day.year, day.month, day.day);
                        final entry = byDay[key];
                        if (entry == null) return null;

                        final color = entry.isPresent
                            ? Colors.green
                            : entry.isAbsent
                            ? Colors.red
                            : Colors.orange;

                        return Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: 0.6),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text('${day.day}'),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedDay != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _SelectedDayInfo(
                      selectedDay: _selectedDay!,
                      entry:
                          byDay[DateTime(
                            _selectedDay!.year,
                            _selectedDay!.month,
                            _selectedDay!.day,
                          )],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectedDayInfo extends StatelessWidget {
  const _SelectedDayInfo({required this.selectedDay, required this.entry});

  final DateTime selectedDay;
  final AttendanceEntry? entry;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd MMM yyyy').format(selectedDay);

    if (entry == null) {
      return Text('No attendance marked for $dateText');
    }

    final statusText = entry!.status.toUpperCase();
    return Text('Attendance on $dateText: $statusText');
  }
}
