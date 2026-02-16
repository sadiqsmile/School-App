import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import 'admin_create_edit_exam_screen.dart';
import 'admin_exam_timetable_screen.dart';
import 'admin_publish_results_screen.dart';

class AdminExamsScreen extends ConsumerStatefulWidget {
  const AdminExamsScreen({super.key});

  @override
  ConsumerState<AdminExamsScreen> createState() => _AdminExamsScreenState();
}

class _AdminExamsScreenState extends ConsumerState<AdminExamsScreen> with SingleTickerProviderStateMixin {
  static const _groups = <String>['primary', 'middle', 'highschool'];

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _groups.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String _cap(String s) => s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));

  @override
  Widget build(BuildContext context) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return yearAsync.when(
      loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (yearId) {
        final groupId = _groups[_tabs.index];

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _open(
              context,
              AdminCreateEditExamScreen(
                yearId: yearId,
                initialGroupId: groupId,
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create Exam'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Exams',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      'Year: $yearId',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabs: [for (final g in _groups) Tab(text: _cap(g))],
                    onTap: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _AdminExamList(
                  yearId: yearId,
                  groupId: groupId,
                  onOpenEdit: (exam) => _open(
                    context,
                    AdminCreateEditExamScreen(
                      yearId: yearId,
                      examId: exam.id,
                      initialGroupId: exam.groupId,
                    ),
                  ),
                  onOpenTimetable: (exam) => _open(
                    context,
                    AdminExamTimetableScreen(
                      yearId: yearId,
                      exam: exam,
                    ),
                  ),
                  onOpenPublishResults: (exam) => _open(
                    context,
                    AdminPublishResultsScreen(
                      yearId: yearId,
                      exam: exam,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminExamList extends ConsumerWidget {
  const _AdminExamList({
    required this.yearId,
    required this.groupId,
    required this.onOpenEdit,
    required this.onOpenTimetable,
    required this.onOpenPublishResults,
  });

  final String yearId;
  final String groupId;
  final ValueChanged<Exam> onOpenEdit;
  final ValueChanged<Exam> onOpenTimetable;
  final ValueChanged<Exam> onOpenPublishResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.read(examServiceProvider).watchExamsForGroup(
          yearId: yearId,
          groupId: groupId,
          onlyActive: false,
        );

    return StreamBuilder<List<Exam>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingView(message: 'Loading exams…'));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final exams = snapshot.data ?? const [];
        if (exams.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No exams for this group yet.\n\nTap “Create Exam” to add one.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: exams.length,
          itemBuilder: (context, i) {
            final e = exams[i];
            final range = _rangeLabel(e.startDate, e.endDate);

            return Card(
              child: ListTile(
                title: Text(e.examName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Group: ${e.groupId}\n$range'),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    _Chip(active: e.isActive),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') onOpenEdit(e);
                        if (v == 'timetable') onOpenTimetable(e);
                        if (v == 'publish') onOpenPublishResults(e);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit Exam')),
                        PopupMenuItem(value: 'timetable', child: Text('Exam Timetable')),
                        PopupMenuItem(value: 'publish', child: Text('Publish Results')),
                      ],
                    ),
                  ],
                ),
                onTap: () => onOpenTimetable(e),
              ),
            );
          },
        );
      },
    );
  }

  String _rangeLabel(DateTime? start, DateTime? end) {
    String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    if (start == null && end == null) return 'Dates: —';
    if (start != null && end == null) return 'Start: ${fmt(start)}';
    if (start == null && end != null) return 'End: ${fmt(end)}';
    return 'Dates: ${fmt(start!)} → ${fmt(end!)}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.outline;
    final label = active ? 'Active' : 'Inactive';
    return Chip(
      label: Text(label),
      side: BorderSide(color: color),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(color: color),
    );
  }
}
