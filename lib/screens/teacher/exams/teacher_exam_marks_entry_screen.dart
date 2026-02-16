import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../models/exam_result.dart';
import '../../../models/year_student.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class TeacherExamMarksEntryScreen extends ConsumerStatefulWidget {
  const TeacherExamMarksEntryScreen({
    super.key,
    required this.yearId,
    required this.exam,
  });

  final String yearId;
  final Exam exam;

  @override
  ConsumerState<TeacherExamMarksEntryScreen> createState() => _TeacherExamMarksEntryScreenState();
}

class _TeacherExamMarksEntryScreenState extends ConsumerState<TeacherExamMarksEntryScreen> {
  String? _selectedClassSectionId; // underscore: class_section
  String? _classId;
  String? _sectionId;

  final _subject = TextEditingController();
  final _maxMarks = TextEditingController(text: '100');
  bool _saving = false;

  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    _subject.dispose();
    _maxMarks.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  ({String classId, String sectionId})? _parseUnderscorePair(String id) {
    final parts = id.split('_');
    if (parts.length != 2) return null;
    final c = parts[0].trim();
    final s = parts[1].trim();
    if (c.isEmpty || s.isEmpty) return null;
    return (classId: c, sectionId: s);
  }

  double? _tryParseDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  TextEditingController _ctrl(String studentId, {String? initial}) {
    final existing = _controllers[studentId];
    if (existing != null) return existing;
    final c = TextEditingController(text: initial ?? '');
    _controllers[studentId] = c;
    return c;
  }

  Future<void> _save({required List<YearStudent> students}) async {
    final authUser = ref.read(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      _snack('Please login again.');
      return;
    }

    final subject = _subject.text.trim();
    final max = _tryParseDouble(_maxMarks.text) ?? 0;

    if (subject.isEmpty) {
      _snack('Subject is required');
      return;
    }
    if (max <= 0) {
      _snack('Max marks must be > 0');
      return;
    }

    final classId = (_classId ?? '').trim();
    final sectionId = (_sectionId ?? '').trim();
    if (classId.isEmpty || sectionId.isEmpty) {
      _snack('Select class/section');
      return;
    }

    final obtainedByStudentId = <String, double?>{};
    for (final s in students) {
      final raw = _controllers[s.base.id]?.text ?? '';
      final val = _tryParseDouble(raw);
      if (val == null) continue;
      if (val < 0) {
        _snack('Marks cannot be negative');
        return;
      }
      if (val > max) {
        _snack('Marks cannot exceed max marks');
        return;
      }
      obtainedByStudentId[s.base.id] = val;
    }

    if (obtainedByStudentId.isEmpty) {
      _snack('Enter marks for at least one student');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(examServiceProvider).upsertSubjectMarksForStudents(
            yearId: widget.yearId,
            examId: widget.exam.id,
            groupId: widget.exam.groupId,
            classId: classId,
            sectionId: sectionId,
            subject: subject,
            maxMarks: max,
            enteredByTeacherUid: authUser.uid,
            students: students,
            obtainedByStudentId: obtainedByStudentId,
          );

      if (!mounted) return;
      _snack('Marks saved');
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
        appBar: AppBar(title: const Text('Enter Marks')),
        body: const Center(child: Text('Please login again.')),
      );
    }

    final assignedStream = ref.read(teacherDataServiceProvider).watchAssignedClassSectionIds(
          teacherUid: authUser.uid,
        );

    final resultsStream = (_classId == null || _sectionId == null)
        ? null
        : ref.read(examServiceProvider).watchResultsForClassSection(
              yearId: widget.yearId,
              examId: widget.exam.id,
              classId: _classId!,
              sectionId: _sectionId!,
            );

    return Scaffold(
      appBar: AppBar(title: Text('Marks • ${widget.exam.examName}')),
      body: _saving
          ? const Center(child: LoadingView(message: 'Saving…'))
          : StreamBuilder<List<String>>(
              stream: assignedStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingView(message: 'Loading assignments…'));
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final classSectionIds = snap.data ?? const [];
                if (classSectionIds.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No class/section assigned yet.\n\nAsk admin to set teacherAssignments.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Keep selection valid.
                if (_selectedClassSectionId == null || !classSectionIds.contains(_selectedClassSectionId)) {
                  _selectedClassSectionId = classSectionIds.first;
                  final parsed = _parseUnderscorePair(_selectedClassSectionId!);
                  _classId = parsed?.classId;
                  _sectionId = parsed?.sectionId;
                }

                final parsed = _selectedClassSectionId == null ? null : _parseUnderscorePair(_selectedClassSectionId!);
                final classId = parsed?.classId;
                final sectionId = parsed?.sectionId;

                final studentsStream = (_selectedClassSectionId == null)
                    ? null
                    : ref.read(teacherDataServiceProvider).watchStudentsForClassSection(
                          yearId: widget.yearId,
                          classSectionId: _selectedClassSectionId!,
                        );

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Group: ${widget.exam.groupId}', style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_selectedClassSectionId),
                              initialValue: _selectedClassSectionId,
                              items: [
                                for (final id in classSectionIds)
                                  DropdownMenuItem(value: id, child: Text(id.replaceAll('_', ' • '))),
                              ],
                              onChanged: (v) {
                                final p = v == null ? null : _parseUnderscorePair(v);
                                setState(() {
                                  _selectedClassSectionId = v;
                                  _classId = p?.classId;
                                  _sectionId = p?.sectionId;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Class/Section',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.groups_2_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _subject,
                              decoration: const InputDecoration(
                                labelText: 'Subject',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.menu_book_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _maxMarks,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              decoration: const InputDecoration(
                                labelText: 'Max Marks',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.score_outlined),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Note: Saving marks does not publish results. Admin publishes later.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (studentsStream == null)
                      const SizedBox.shrink()
                    else
                      StreamBuilder<List<YearStudent>>(
                        stream: studentsStream,
                        builder: (context, studentsSnap) {
                          if (studentsSnap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: LoadingView(message: 'Loading students…')),
                            );
                          }
                          if (studentsSnap.hasError) {
                            return Center(child: Text('Error: ${studentsSnap.error}'));
                          }

                          final all = studentsSnap.data ?? const [];
                          final students = all.where((s) => s.base.groupId == widget.exam.groupId).toList();
                          if (students.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No students found for this exam group in the selected class/section.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          return StreamBuilder<List<ExamResult>>(
                            stream: resultsStream,
                            builder: (context, resultsSnap) {
                              final results = (resultsSnap.data ?? const [])
                                  .where((r) => r.groupId == widget.exam.groupId)
                                  .toList();
                              final byStudentId = {for (final r in results) r.studentId: r};

                              // Pre-fill controllers once per subject change.
                              final subject = _subject.text.trim().toLowerCase();
                              for (final s in students) {
                                final existing = byStudentId[s.base.id];
                                final match = existing?.subjects.where((x) => x.subject.toLowerCase() == subject).toList();
                                final initial = (subject.isEmpty || match == null || match.isEmpty)
                                    ? null
                                    : match.first.obtainedMarks.toString();
                                final c = _controllers[s.base.id];
                                if (c == null) {
                                  _ctrl(s.base.id, initial: initial);
                                }
                              }

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Marks Entry • Class ${classId ?? ''} / ${sectionId ?? ''}',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 12),
                                      for (final s in students)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(s.base.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 2,
                                                child: TextField(
                                                  controller: _ctrl(s.base.id),
                                                  keyboardType: TextInputType.number,
                                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                                  decoration: const InputDecoration(
                                                    labelText: 'Obtained',
                                                    border: OutlineInputBorder(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 48,
                                        child: FilledButton.icon(
                                          onPressed: () => _save(students: students),
                                          icon: const Icon(Icons.save_outlined),
                                          label: const Text('Save marks'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            ),
    );
  }
}
