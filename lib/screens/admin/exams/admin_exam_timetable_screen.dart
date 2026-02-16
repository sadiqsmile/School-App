import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../models/exam_timetable.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import 'admin_exam_timetable_editor_screen.dart';

class AdminExamTimetableScreen extends ConsumerWidget {
  const AdminExamTimetableScreen({
    super.key,
    required this.yearId,
    required this.exam,
  });

  final String yearId;
  final Exam exam;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.read(examServiceProvider).watchTimetable(
          yearId: yearId,
          examId: exam.id,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('Timetable • ${exam.examName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(
          context,
          AdminExamTimetableEditorScreen(
            yearId: yearId,
            exam: exam,
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add class/section'),
      ),
      body: StreamBuilder<List<ExamTimetable>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingView(message: 'Loading timetable…'));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No timetable created yet.\n\nTap “Add class/section” to start.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final t = items[i];
              final subtitle = '${t.schedule.length} schedule item(s)';

              return Card(
                child: ListTile(
                  title: Text('Class ${t.classId} • Section ${t.sectionId}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(subtitle),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(t.isPublished ? 'Published' : 'Draft'),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => _open(
                          context,
                          AdminExamTimetableEditorScreen(
                            yearId: yearId,
                            exam: exam,
                            classId: t.classId,
                            sectionId: t.sectionId,
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  onTap: () => _open(
                    context,
                    AdminExamTimetableEditorScreen(
                      yearId: yearId,
                      exam: exam,
                      classId: t.classId,
                      sectionId: t.sectionId,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
