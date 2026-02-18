import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/student_base.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/attendance_service.dart';
import '../../../widgets/loading_view.dart';

class TeacherMarkAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherMarkAttendanceScreen({
    super.key,
    required this.yearId,
    required this.classId,
    required this.sectionId,
    required this.date,
  });

  final String yearId;
  final String classId;
  final String sectionId;
  final DateTime date;

  @override
  ConsumerState<TeacherMarkAttendanceScreen> createState() =>
      _TeacherMarkAttendanceScreenState();
}

class _TeacherMarkAttendanceScreenState
    extends ConsumerState<TeacherMarkAttendanceScreen> {
  final Map<String, bool> _present = {};
  bool _initialized = false;
  bool _saving = false;

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _initializeFrom({
    required List<StudentBase> students,
    required bool dayExists,
    required Map<String, dynamic>? summaryData,
  }) {
    if (_initialized) return;

    // Default to Present to make marking fast.
    final next = <String, bool>{};
    for (final s in students) {
      next[s.id] = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _present
          ..clear()
          ..addAll(next);
        _initialized = true;
      });
      if (dayExists) {
        _snack(
          'Attendance already exists for this date. Save will overwrite if you confirm.',
        );
      }
    });
  }

  Future<void> _save({
    required bool overwriteIfExists,
    required List<StudentBase> students,
  }) async {
    final teacher = ref.read(firebaseAuthUserProvider).asData?.value;
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      final records = <String, String>{};
      for (final e in _present.entries) {
        records[e.key] = e.value ? 'P' : 'A';
      }

      await ref
          .read(attendanceServiceProvider)
          .saveAttendanceDayV3(
            yearId: widget.yearId,
            classId: widget.classId,
            sectionId: widget.sectionId,
            date: widget.date,
            markedByUid: teacher.uid,
            students: students,
            records: records,
            overwriteIfExists: overwriteIfExists,
          );

      if (!mounted) return;
      _snack('Attendance saved');
    } on AttendanceAlreadyMarkedException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (e) {
      if (!mounted) return;
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mark Attendance')),
        body: const Center(child: Text('Please login again.')),
      );
    }

    final attendance = ref.read(attendanceServiceProvider);
    final studentsStream = attendance.watchStudentsForClassSection(
      classId: widget.classId,
      sectionId: widget.sectionId,
    );
    final summaryStream = attendance.watchAttendanceSummaryDay(
      yearId: widget.yearId,
      classId: widget.classId,
      sectionId: widget.sectionId,
      date: widget.date,
    );

    final dateText = DateFormat('dd MMM yyyy').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance • ${widget.classId}-${widget.sectionId}'),
      ),
      body: StreamBuilder<List<StudentBase>>(
        stream: studentsStream,
        builder: (context, studentsSnap) {
          if (studentsSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: LoadingView(message: 'Loading students…'),
            );
          }
          if (studentsSnap.hasError) {
            return Center(child: Text('Error: ${studentsSnap.error}'));
          }

          final students = studentsSnap.data ?? const <StudentBase>[];
          if (students.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No students found for this class/section.\n\nAsk admin to add students and set their class/section.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder(
            stream: summaryStream,
            builder: (context, daySnap) {
              if (daySnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: LoadingView(message: 'Loading attendance…'),
                );
              }
              if (daySnap.hasError) {
                return Center(child: Text('Error: ${daySnap.error}'));
              }

              final summaryDoc = daySnap.data;
              final exists = summaryDoc?.exists == true;
              final data = summaryDoc?.data();

              _initializeFrom(
                students: students,
                dayExists: exists,
                summaryData: data,
              );

              if (!_initialized) {
                return const Center(child: LoadingView(message: 'Preparing…'));
              }

              final total = students.length;
              final presentCount = _present.values.where((v) => v).length;
              final absentCount = total - presentCount;

                  final markedBy = data == null
                    ? null
                    : (data['markedByUid'] as String?) ??
                      (data['markedByTeacherUid'] as String?);
              final markedInfo = exists && markedBy != null
                  ? 'Marked by: $markedBy'
                  : null;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date: $dateText',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  if (markedInfo != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      markedInfo,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    children: [
                                      _CountChip(
                                        label: 'Total',
                                        value: total.toString(),
                                      ),
                                      _CountChip(
                                        label: 'Present',
                                        value: presentCount.toString(),
                                      ),
                                      _CountChip(
                                        label: 'Absent',
                                        value: absentCount.toString(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      if (exists) {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text(
                                              'Overwrite attendance?',
                                            ),
                                            content: Text(
                                              'Attendance is already marked for $dateText (${widget.classId}-${widget.sectionId}).\n\nDo you want to overwrite it?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                child: const Text('Overwrite'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok != true) return;
                                        await _save(
                                          overwriteIfExists: true,
                                          students: students,
                                        );
                                      } else {
                                        await _save(
                                          overwriteIfExists: false,
                                          students: students,
                                        );
                                      }
                                    },
                              icon: _saving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final s = students[index];
                        final isPresent = _present[s.id] ?? true;

                        return Card(
                          child: ListTile(
                            title: Text(
                              s.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'Admission: ${s.admissionNo ?? '-'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isPresent ? 'P' : 'A',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(width: 8),
                                Switch.adaptive(
                                  value: isPresent,
                                  onChanged: _saving
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _present[s.id] = v;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
