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
      appBar: AppBar(
        title: const Text('Timetable'),
        elevation: 0,
      ),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Academic Year',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  yearId,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.schedule, color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Selection Card
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('group-${_groupId ?? ''}'),
                              initialValue: allowedGroups.contains(_groupId) ? _groupId : null,
                              decoration: InputDecoration(
                                labelText: 'Group',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                prefixIcon: const Icon(Icons.groups_2_outlined),
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
                                width: 240,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('class-${selected ?? ''}'),
                                  initialValue: selected,
                                  decoration: InputDecoration(
                                    labelText: 'Class',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                    prefixIcon: const Icon(Icons.class_outlined),
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
                                width: 240,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('section-${selected ?? ''}'),
                                  initialValue: selected,
                                  decoration: InputDecoration(
                                    labelText: 'Section',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                    prefixIcon: const Icon(Icons.segment_outlined),
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
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: (_groupId == null || _classId == null || _sectionId == null)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Select Timetable',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Pick a group, class, and section to view.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
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
