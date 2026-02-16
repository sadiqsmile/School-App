import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../models/parent_student.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import 'parent_exam_details_screen.dart';

class ParentExamsScreen extends ConsumerStatefulWidget {
  const ParentExamsScreen({super.key});

  @override
  ConsumerState<ParentExamsScreen> createState() => _ParentExamsScreenState();
}

class _ParentExamsScreenState extends ConsumerState<ParentExamsScreen> {
  ParentStudent? _selected;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return FutureBuilder<String?>(
      future: ref.read(authServiceProvider).getParentMobile(),
      builder: (context, parentSnap) {
        if (parentSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: LoadingView(message: 'Loading…')));
        }

        final parentMobile = parentSnap.data;
        if (parentMobile == null || parentMobile.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Exams')),
            body: const Center(child: Text('Please login again.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Exams')),
          body: yearAsync.when(
            loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (yearId) {
              final studentsStream = ref
                  .read(parentDataServiceProvider)
                  .watchMyStudents(yearId: yearId, parentUid: parentMobile);

              return StreamBuilder<List<ParentStudent>>(
                stream: studentsStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingView(message: 'Loading children…'));
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  final children = snap.data ?? const [];
                  if (children.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No student linked to this parent for the active academic year.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  _selected ??= children.first;
                  if (_selected != null && !children.any((x) => x.base.id == _selected!.base.id)) {
                    _selected = children.first;
                  }

                  final groupId = (_selected!.base.groupId ?? '').trim();
                  if (groupId.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Student group is missing.\n\nAsk admin to set group for this student.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final examsStream = ref.read(examServiceProvider).watchExamsForGroup(
                        yearId: yearId,
                        groupId: groupId,
                        onlyActive: true,
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
                              DropdownButtonFormField<String>(
                                key: ValueKey(_selected!.base.id),
                                initialValue: _selected!.base.id,
                                items: [
                                  for (final c in children)
                                    DropdownMenuItem(
                                      value: c.base.id,
                                      child: Text(c.base.fullName),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _selected = children.firstWhere((x) => x.base.id == v);
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Select child',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Group: $groupId', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<List<Exam>>(
                        stream: examsStream,
                        builder: (context, examsSnap) {
                          if (examsSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: LoadingView(message: 'Loading exams…'));
                          }
                          if (examsSnap.hasError) {
                            return Center(child: Text('Error: ${examsSnap.error}'));
                          }

                          final exams = examsSnap.data ?? const [];
                          if (exams.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No exams published for this group yet.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              for (final e in exams)
                                Card(
                                  child: ListTile(
                                    title: Text(e.examName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text('Tap to view timetable / results'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _open(
                                      context,
                                      ParentExamDetailsScreen(
                                        yearId: yearId,
                                        exam: e,
                                        student: _selected!,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
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
