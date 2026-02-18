import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import 'student_exam_details_screen.dart';

class StudentExamsScreen extends ConsumerWidget {
  const StudentExamsScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String _rangeLabel(DateTime? start, DateTime? end) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    if (start == null && end == null) return 'Dates: —';
    if (start != null && end == null) return 'Start: ${fmt(start)}';
    if (start == null && end != null) return 'End: ${fmt(end)}';
    return '${fmt(start!)} → ${fmt(end!)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final appUserAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exams')),
      body: yearAsync.when(
        loading: () =>
            const Center(child: LoadingView(message: 'Loading academic year…')),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (yearId) {
          return appUserAsync.when(
            loading: () =>
                const Center(child: LoadingView(message: 'Loading profile…')),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (user) {
              if (user.role != UserRole.student) {
                return const Center(
                  child: Text('Only students can access this screen.'),
                );
              }

              final studentId = user.id;
              final groupId = user.groupId ?? '';

              if (groupId.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Student group is missing.\n\nAsk admin to set your group.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final stream =
                  ref.read(examServiceProvider).watchExamsForGroup(
                        yearId: yearId,
                        groupId: groupId,
                        onlyActive: true,
                      );

              return StreamBuilder<List<Exam>>(
                stream: stream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: LoadingView(message: 'Loading exams…'));
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  final exams = snap.data ?? const [];

                  if (exams.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No active exams available yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: exams.length,
                    itemBuilder: (context, i) {
                      final exam = exams[i];
                      final isUpcoming = exam.startDate?.isAfter(DateTime.now()) ??
                          false;

                      return Card(
                        child: ListTile(
                          title: Text(
                            exam.examName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            _rangeLabel(exam.startDate, exam.endDate),
                          ),
                          trailing: Icon(
                            isUpcoming ? Icons.schedule : Icons.check_circle,
                            color:
                                isUpcoming ? Colors.orange : Colors.green,
                          ),
                          onTap: () => _open(
                            context,
                            StudentExamDetailsScreen(
                              exam: exam,
                              studentId: studentId,
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
