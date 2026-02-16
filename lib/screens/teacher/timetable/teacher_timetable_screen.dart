import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/timetable_service.dart';
import '../../../widgets/loading_view.dart';
import '../../shared/timetable/timetable_widgets.dart';

class TeacherTimetableScreen extends ConsumerStatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  ConsumerState<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends ConsumerState<TeacherTimetableScreen> {
  String? _groupId;
  String? _classId;
  String? _sectionId;

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timetable')),
        body: const Center(child: Text('Please login again.')),
      );
    }

    final appUserAsync = ref.watch(appUserProvider);
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    final adminData = ref.read(adminDataServiceProvider);
    final classesStream = adminData.watchClasses();
    final sectionsStream = adminData.watchSections();

    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      body: appUserAsync.when(
        loading: () => const Center(child: LoadingView(message: 'Loading profile…')),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (appUser) {
          final allowedGroups = appUser.assignedGroups;
          if (allowedGroups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No groups assigned to this teacher yet.\n\nAsk admin to set assignedGroups (primary/middle/highschool).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          _groupId ??= allowedGroups.first;

          return yearAsync.when(
            loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (yearId) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('group-${_groupId ?? ''}'),
                                initialValue: allowedGroups.contains(_groupId) ? _groupId : null,
                                decoration: const InputDecoration(
                                  labelText: 'Group',
                                  prefixIcon: Icon(Icons.groups_2_outlined),
                                ),
                                items: [
                                  for (final g in allowedGroups)
                                    DropdownMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _groupId = v),
                              ),
                            ),
                            StreamBuilder(
                              stream: classesStream,
                              builder: (context, snap) {
                                final docs = snap.data?.docs ?? const [];
                                final ids = docs.map((d) => d.id).toSet();
                                final selected = (_classId != null && ids.contains(_classId)) ? _classId : null;

                                return SizedBox(
                                  width: 260,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey('class-${selected ?? ''}'),
                                    initialValue: selected,
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      prefixIcon: Icon(Icons.class_outlined),
                                    ),
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text((d.data()['name'] as String?) ?? d.id),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _classId = v),
                                  ),
                                );
                              },
                            ),
                            StreamBuilder(
                              stream: sectionsStream,
                              builder: (context, snap) {
                                final docs = snap.data?.docs ?? const [];
                                final ids = docs.map((d) => d.id).toSet();
                                final selected = (_sectionId != null && ids.contains(_sectionId)) ? _sectionId : null;

                                return SizedBox(
                                  width: 260,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey('section-${selected ?? ''}'),
                                    initialValue: selected,
                                    decoration: const InputDecoration(
                                      labelText: 'Section',
                                      prefixIcon: Icon(Icons.segment_outlined),
                                    ),
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text((d.data()['name'] as String?) ?? d.id),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _sectionId = v),
                                  ),
                                );
                              },
                            ),
                            Text(
                              'Year: $yearId',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: (_groupId == null || _classId == null || _sectionId == null)
                        ? const Center(child: Text('Select Group, Class, and Section to view timetable.'))
                        : _TeacherTimetableBody(
                            yearId: yearId,
                            groupId: _groupId!,
                            classId: _classId!,
                            sectionId: _sectionId!,
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

class _TeacherTimetableBody extends ConsumerWidget {
  const _TeacherTimetableBody({
    required this.yearId,
    required this.groupId,
    required this.classId,
    required this.sectionId,
  });

  final String yearId;
  final String groupId;
  final String classId;
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.read(timetableServiceProvider).watchTimetable(
          yearId: yearId,
          groupId: groupId,
          classId: classId,
          sectionId: sectionId,
        );

    return StreamBuilder(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingView(message: 'Loading timetable…'));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final data = snap.data?.data() ?? const <String, Object?>{};
        final days = parseDays(data['days']);

        return DefaultTabController(
          length: TimetableDays.keys.length,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  '$groupId • $classId-$sectionId',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(snap.data?.exists == true ? 'Updated' : 'No timetable uploaded yet.'),
              ),
              TabBar(
                isScrollable: true,
                tabs: [
                  for (final k in TimetableDays.keys) Tab(text: TimetableDays.label(k)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final dayKey in TimetableDays.keys)
                      TimetableDayView(
                        dayKey: dayKey,
                        items: days[dayKey] ?? const <TimetablePeriod>[],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
