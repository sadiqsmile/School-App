import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/attendance_pa_entry.dart';
import '../../../models/student_base.dart';
import '../../../config/app_config.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class ParentAttendanceScreen extends ConsumerStatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  ConsumerState<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends ConsumerState<ParentAttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _selectedStudentId;

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return FutureBuilder<String?>(
      future: ref.read(authServiceProvider).getParentMobile(),
      builder: (context, mobileSnap) {
        if (mobileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: LoadingView(message: 'Loading…')));
        }

        final parentMobile = mobileSnap.data;
        if (parentMobile == null || parentMobile.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Attendance')),
            body: const Center(child: Text('Please login again.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Attendance')),
          body: yearAsync.when(
            loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (yearId) {
              final childrenStream = ref
                  .read(parentDataServiceProvider)
                  .watchLinkedChildrenBaseStudents(parentMobile: parentMobile);

              return StreamBuilder<List<StudentBase>>(
                stream: childrenStream,
                builder: (context, childSnap) {
                  if (childSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingView(message: 'Loading linked students…'));
                  }
                  if (childSnap.hasError) {
                    return Center(child: Text('Error: ${childSnap.error}'));
                  }

                  final children = childSnap.data ?? const <StudentBase>[];
                  if (children.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No child linked to this parent yet.\n\nAsk admin to link students to your parent account (parents/{mobile}.children).',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  _selectedStudentId ??= children.first.id;
                  if (!children.any((c) => c.id == _selectedStudentId)) {
                    _selectedStudentId = children.first.id;
                  }

                  final selected = children.firstWhere((c) => c.id == _selectedStudentId);

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(AppConfig.schoolId)
                        .collection('students')
                        .doc(selected.id)
                        .get(),
                    builder: (context, studentDocSnap) {
                      if (studentDocSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: LoadingView(message: 'Loading student…'));
                      }
                      if (studentDocSnap.hasError) {
                        return Center(child: Text('Error: ${studentDocSnap.error}'));
                      }

                      final studentData = studentDocSnap.data?.data() ?? const <String, dynamic>{};
                      final classId =
                          ((studentData['class'] as String?) ?? (studentData['classId'] as String?))?.trim();
                      final sectionId = ((studentData['section'] as String?) ??
                              (studentData['sectionId'] as String?))
                          ?.trim();

                      if (classId == null || classId.isEmpty || sectionId == null || sectionId.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _StudentPickerCard(
                              month: _month,
                              onPrev: _prevMonth,
                              onNext: _nextMonth,
                              children: children,
                              selectedStudentId: _selectedStudentId!,
                              onChanged: (id) => setState(() => _selectedStudentId = id),
                            ),
                            const SizedBox(height: 12),
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'This student does not have class/section set in schools/{schoolId}/students/{studentId}.\n\nAttendance view needs class + section to locate day documents.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      final entriesStream = ref.read(attendanceServiceProvider).watchStudentAttendanceForMonth(
                            yearId: yearId,
                            classId: classId,
                            sectionId: sectionId,
                            studentId: selected.id,
                            month: _month,
                          );

                      return StreamBuilder<List<AttendancePAEntry>>(
                        stream: entriesStream,
                        builder: (context, attSnap) {
                          if (attSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: LoadingView(message: 'Loading attendance…'));
                          }
                          if (attSnap.hasError) {
                            return Center(child: Text('Error: ${attSnap.error}'));
                          }

                          final entries = attSnap.data ?? const <AttendancePAEntry>[];
                          final present = entries.where((e) => e.status == 'P').length;
                          final absent = entries.where((e) => e.status == 'A').length;
                          final marked = present + absent;
                          final percent = marked == 0 ? 0.0 : (present / marked) * 100;

                          final statusByDay = <int, String?>{};
                          for (final e in entries) {
                            statusByDay[e.date.day] = e.status;
                          }

                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _StudentPickerCard(
                                month: _month,
                                onPrev: _prevMonth,
                                onNext: _nextMonth,
                                children: children,
                                selectedStudentId: _selectedStudentId!,
                                onChanged: (id) => setState(() => _selectedStudentId = id),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Summary',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          Chip(label: Text('Present: $present')),
                                          Chip(label: Text('Absent: $absent')),
                                          Chip(label: Text('Marked days: $marked')),
                                          Chip(label: Text('Percentage: ${percent.toStringAsFixed(1)}%')),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Class/Section: $classId-$sectionId • Year: $yearId',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _MonthCalendarCard(
                                month: _month,
                                statusByDay: statusByDay,
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'List',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 8),
                                      if (entries.isEmpty)
                                        const Text('No attendance marked for this month yet.'),
                                      if (entries.isNotEmpty)
                                        ...entries.map((e) {
                                          final label = DateFormat('dd MMM yyyy').format(e.date);
                                          final status = e.status ?? '—';
                                          final color = switch (e.status) {
                                            'P' => Colors.green,
                                            'A' => Colors.red,
                                            _ => Colors.grey,
                                          };
                                          return ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(label),
                                            trailing: Text(
                                              status,
                                              style: TextStyle(fontWeight: FontWeight.w900, color: color),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _StudentPickerCard extends StatelessWidget {
  const _StudentPickerCard({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.children,
    required this.selectedStudentId,
    required this.onChanged,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final List<StudentBase> children;
  final String selectedStudentId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final monthText = DateFormat('MMMM yyyy').format(month);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select child',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedStudentId),
              initialValue: selectedStudentId,
              items: [
                for (final c in children)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.fullName} (${c.admissionNo ?? '-'})'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              decoration: const InputDecoration(
                labelText: 'Child',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendarCard extends StatelessWidget {
  const _MonthCalendarCard({
    required this.month,
    required this.statusByDay,
  });

  final DateTime month;
  final Map<int, String?> statusByDay;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Dart weekday: Mon=1..Sun=7; we want grid starting Mon.
    final startOffset = firstDay.weekday - 1;

    final cells = <Widget>[];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final w in weekdays) {
      cells.add(
        Center(
          child: Text(
            w,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final status = statusByDay[day];
      final color = switch (status) {
        'P' => Colors.green,
        'A' => Colors.red,
        _ => Colors.grey,
      };

      cells.add(
        Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Container(
                height: 18,
                width: 18,
                decoration: BoxDecoration(
                  color: status == null ? Colors.transparent : color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
                child: Center(
                  child: Text(
                    status ?? '',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}
