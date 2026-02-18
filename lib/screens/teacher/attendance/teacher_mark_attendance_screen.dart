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
        title: Text('${widget.classId} • ${widget.sectionId}'),
        elevation: 0,
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('No Students', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('No students found for this class/section.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder(
            stream: summaryStream,
            builder: (context, daySnap) {
              if (daySnap.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingView(message: 'Loading attendance…'));
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
              final markedBy = data == null ? null : (data['markedByUid'] as String?) ?? (data['markedByTeacherUid'] as String?);

              return Column(
                children: [
                  // Premium Gradient Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateText,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${widget.classId} • ${widget.sectionId}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (exists && markedBy != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Marked by: $markedBy',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.assignment, color: Colors.white, size: 28),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Stats Pills
                          Row(
                            children: [
                              _buildStatPill(context, 'Total', total.toString(), Colors.white),
                              const SizedBox(width: 12),
                              _buildStatPill(context, 'Present', presentCount.toString(), Colors.green.shade100),
                              const SizedBox(width: 12),
                              _buildStatPill(context, 'Absent', absentCount.toString(), Colors.red.shade100),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Student List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final s = students[index];
                        final isPresent = _present[s.id] ?? true;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isPresent
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isPresent
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.red.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Adm: ${s.admissionNo ?? '-'}',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: _saving
                                      ? null
                                      : () {
                                          setState(() {
                                            _present[s.id] = !isPresent;
                                          });
                                        },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isPresent
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isPresent ? 'Present' : 'Absent',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
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
      // Sticky Bottom Bar
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
            child: StreamBuilder<List<StudentBase>>(
              stream: studentsStream,
              builder: (context, studentsSnap) {
                final students = studentsSnap.data ?? const <StudentBase>[];
                if (students.isEmpty) {
                  return const SizedBox.shrink();
                }

                final total = students.length;
                final presentCount = _present.values.where((v) => v).length;
                final absentCount = total - presentCount;

                return Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Present', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                Text(presentCount.toString(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Absent', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                Text(absentCount.toString(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final students = studentsSnap.data ?? const <StudentBase>[];
                              if (students.isEmpty) return;
                              await _save(
                                overwriteIfExists: true,
                                students: students,
                              );
                            },
                      icon: _saving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(BuildContext context, String label, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
          ),
        ],
      ),
    );
  }
}
