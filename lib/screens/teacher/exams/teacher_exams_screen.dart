import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import 'teacher_exam_marks_entry_screen.dart';

class TeacherExamsScreen extends ConsumerWidget {
  const TeacherExamsScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String _rangeLabel(DateTime? start, DateTime? end) {
    String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    if (start == null && end == null) return 'Dates: —';
    if (start != null && end == null) return 'Start: ${fmt(start)}';
    if (start == null && end != null) return 'End: ${fmt(end)}';
    return 'Dates: ${fmt(start!)} → ${fmt(end!)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final appUserAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Enter Exam Marks')),
      body: yearAsync.when(
        loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (yearId) {
          return appUserAsync.when(
            loading: () => const Center(child: LoadingView(message: 'Loading profile…')),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (user) {
              if (user.role != UserRole.teacher) {
                return const Center(child: Text('Only teachers can access this screen.'));
              }

              final groups = user.assignedGroups;
              if (groups.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No assigned groups found for this teacher.\n\nAsk admin to set assignedGroups.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final stream = ref.read(examServiceProvider).watchExamsForGroups(
                    yearId: yearId,
                    groupIds: groups,
                    onlyActive: true,
                  );

              return StreamBuilder<List<Exam>>(
                stream: stream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingView(message: 'Loading exams…'));
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  final exams = (snap.data ?? const [])
                      .where((e) => groups.contains(e.groupId))
                      .toList();

                  if (exams.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No active exams available for your groups yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: exams.length,
                    itemBuilder: (context, i) {
                      final e = exams[i];
                      return Card(
                        child: ListTile(
                          title: Text(e.examName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('Group: ${e.groupId}\n${_rangeLabel(e.startDate, e.endDate)}'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            context,
                            TeacherExamMarksEntryScreen(
                              yearId: yearId,
                              exam: e,
                            ),
                          ),
                        ),
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
  }
}
