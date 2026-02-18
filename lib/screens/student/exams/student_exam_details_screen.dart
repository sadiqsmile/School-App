import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../models/exam_result.dart';
import '../../../models/exam_timetable.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class StudentExamDetailsScreen extends ConsumerWidget {
  const StudentExamDetailsScreen({
    super.key,
    required this.exam,
    required this.studentId,
  });

  final Exam exam;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(exam.examName),
        elevation: 0,
      ),
      body: yearAsync.when(
        loading: () =>
            const Center(child: LoadingView(message: 'Loading…')),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (yearId) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exam Info Section
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exam Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Group', exam.groupId),
                      _buildInfoRow(
                        'Start Date',
                        exam.startDate != null
                            ? "${exam.startDate!.day}/${exam.startDate!.month}/${exam.startDate!.year}"
                            : 'N/A',
                      ),
                      _buildInfoRow(
                        'End Date',
                        exam.endDate != null
                            ? "${exam.endDate!.day}/${exam.endDate!.month}/${exam.endDate!.year}"
                            : 'N/A',
                      ),
                    ],
                  ),
                ),

                // Timetable Section
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Exam Timetable',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildTimetableSection(ref, context, yearId),

                // Results Section
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'My Results',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildResultsSection(ref, context, yearId),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableSection(
    WidgetRef ref,
    BuildContext context,
    String yearId,
  ) {
    // Get school and class info from student
    final appUserAsync = ref.watch(appUserProvider);

    return appUserAsync.when(
      loading: () =>
          const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingView(message: 'Loading timetable…'),
          ),
      error: (e, _) =>
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $e'),
          ),
      data: (user) {
        final classId = user.classId;
        final sectionId = user.sectionId;

        if (classId == null || classId.isEmpty || sectionId == null || sectionId.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Class/Section information missing.'),
          );
        }

        final timetableStream = ref
            .read(examServiceProvider)
            .watchTimetableForClassSection(
              yearId: yearId,
              examId: exam.id,
              classId: classId,
              sectionId: sectionId,
            );

        return StreamBuilder<ExamTimetable?>(
          stream: timetableStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingView(message: 'Loading…'),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snap.error}'),
              );
            }

            final timetable = snap.data;
            if (timetable == null || timetable.schedule.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('No timetable available yet.'),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: timetable.schedule.length,
                itemBuilder: (context, index) {
                  final item = timetable.schedule[index];
                    final d = item.date;
                    final dateStr = "${d.day}/${d.month}/${d.year}";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        item.subject,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Date: $dateStr'),
                      trailing: const Icon(Icons.calendar_today),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResultsSection(
    WidgetRef ref,
    BuildContext context,
    String yearId,
  ) {
    final appUserAsync = ref.watch(appUserProvider);

    return appUserAsync.when(
      loading: () =>
          const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingView(message: 'Loading results…'),
          ),
      error: (e, _) =>
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $e'),
          ),
      data: (user) {
        final classId = user.classId;
        final sectionId = user.sectionId;

        if (classId == null ||
            classId.isEmpty ||
            sectionId == null ||
            sectionId.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Class/Section information missing.'),
          );
        }

        final resultStream = ref
            .read(examServiceProvider)
            .watchResultForStudent(
              yearId: yearId,
              examId: exam.id,
              studentId: studentId,
            );

        return StreamBuilder<ExamResult?>(
          stream: resultStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingView(message: 'Loading…'),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snap.error}'),
              );
            }

            final result = snap.data;

            if (result == null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Results not yet available.\n\nChecking back soon…',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!result.isPublished) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Results are being compiled.\n\nThey will be visible soon.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Subject Marks Table
                  Card(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Subject-wise Marks',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Divider(height: 0),
                        ...result.subjects.map((subject) {
                          final percentage = subject.maxMarks > 0
                              ? (subject.obtainedMarks / subject.maxMarks * 100)
                              : 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    subject.subject,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${subject.obtainedMarks.toStringAsFixed(1)}/${subject.maxMarks.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    '${percentage.toStringAsFixed(0)}%',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: percentage >= 80
                                          ? Colors.green
                                          : percentage >= 60
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Overall Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Total Marks',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              result.total.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Percentage',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${result.percentage.toStringAsFixed(2)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Grade',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                result.grade,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
