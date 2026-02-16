import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../models/exam_result.dart';
import '../../../models/exam_timetable.dart';
import '../../../models/parent_student.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class ParentExamDetailsScreen extends ConsumerWidget {
  const ParentExamDetailsScreen({
    super.key,
    required this.yearId,
    required this.exam,
    required this.student,
  });

  final String yearId;
  final Exam exam;
  final ParentStudent student;

  ({String classId, String sectionId})? _classSection() {
    final c = student.base.classId;
    final s = student.base.sectionId;
    if ((c ?? '').trim().isNotEmpty && (s ?? '').trim().isNotEmpty) {
      return (classId: c!.trim(), sectionId: s!.trim());
    }

    // fallback from year.classSectionId: "5_A"
    final parts = student.year.classSectionId.split('_');
    if (parts.length == 2) {
      final c2 = parts[0].trim();
      final s2 = parts[1].trim();
      if (c2.isNotEmpty && s2.isNotEmpty) return (classId: c2, sectionId: s2);
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = _classSection();
    if (cs == null) {
      return Scaffold(
        appBar: AppBar(title: Text(exam.examName)),
        body: const Center(child: Text('Student class/section is missing.')),
      );
    }

    final timetableStream = ref.read(examServiceProvider).watchTimetableForClassSection(
          yearId: yearId,
          examId: exam.id,
          classId: cs.classId,
          sectionId: cs.sectionId,
        );

    final resultStream = ref.read(examServiceProvider).watchResultForStudent(
          yearId: yearId,
          examId: exam.id,
          studentId: student.base.id,
        );

    return Scaffold(
      appBar: AppBar(title: Text(exam.examName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: student.base.photoUrl == null ? null : NetworkImage(student.base.photoUrl!),
                child: student.base.photoUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(student.base.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Class ${cs.classId} • Section ${cs.sectionId} • Group ${student.base.groupId ?? exam.groupId}'),
            ),
          ),
          const SizedBox(height: 12),
          Text('Exam Timetable', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          StreamBuilder<ExamTimetable?>(
            stream: timetableStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: LoadingView(message: 'Loading timetable…')));
              }
              if (snap.hasError) {
                return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snap.error}')));
              }

              final t = snap.data;
              if (t == null || t.schedule.isEmpty) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Timetable not available yet.')));
              }
              if (!t.isPublished) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Timetable is not published yet.')));
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final item in t.schedule)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${item.date.day.toString().padLeft(2, '0')}-${item.date.month.toString().padLeft(2, '0')}-${item.date.year} • ${item.startTime} - ${item.endTime}',
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text('Exam Result', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          StreamBuilder<ExamResult?>(
            stream: resultStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: LoadingView(message: 'Loading results…')));
              }
              if (snap.hasError) {
                return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snap.error}')));
              }

              final r = snap.data;
              if (r == null) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Result not entered yet.')));
              }
              if (!r.isPublished) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Result not published yet.')));
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Total: ${r.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Percentage: ${r.percentage.toStringAsFixed(2)}%'),
                      const SizedBox(height: 4),
                      Text('Grade: ${r.grade}'),
                      const Divider(height: 24),
                      if (r.subjects.isEmpty) const Text('No subject marks found.'),
                      for (final s in r.subjects)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('Max: ${s.maxMarks} • Obtained: ${s.obtainedMarks}'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
