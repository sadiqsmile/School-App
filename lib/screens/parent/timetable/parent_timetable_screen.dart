import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../models/student_base.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/timetable_service.dart';
import '../../../widgets/loading_view.dart';
import '../../shared/timetable/timetable_widgets.dart';

class ParentTimetableScreen extends ConsumerStatefulWidget {
  const ParentTimetableScreen({super.key});

  @override
  ConsumerState<ParentTimetableScreen> createState() => _ParentTimetableScreenState();
}

class _ParentTimetableScreenState extends ConsumerState<ParentTimetableScreen> {
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return FutureBuilder<String?>(
      future: ref.read(authServiceProvider).getParentMobile(),
      builder: (context, mobileSnap) {
        if (mobileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: LoadingView(message: 'Loading…')));
        }

        final parentMobile = mobileSnap.data;
        if (parentMobile == null || parentMobile.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Timetable')),
            body: const Center(child: Text('Please login again.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Timetable'),
            elevation: 0,
          ),
          body: yearAsync.when(
            loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (yearId) {
              final childrenStream = ref
                  .read(parentDataServiceProvider)
                  .watchLinkedChildrenBaseStudents(parentMobile: parentMobile);

              return StreamBuilder<List<StudentBase>>(
                stream: childrenStream,
                builder: (context, childSnap) {
                  if (childSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingView(message: 'Loading linked students…'));
                  }
                  if (childSnap.hasError) {
                    return Center(child: Text('Error: ${childSnap.error}'));
                  }

                  final children = childSnap.data ?? const <StudentBase>[];
                  if (children.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.child_friendly, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No Linked Students',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No child linked to this parent yet.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  _selectedStudentId ??= children.first.id;
                  if (!children.any((c) => c.id == _selectedStudentId)) {
                    _selectedStudentId = children.first.id;
                  }

                  final selected = children.firstWhere((c) => c.id == _selectedStudentId);

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(AppConfig.schoolId)
                        .collection('students')
                        .doc(selected.id)
                        .get(),
                    builder: (context, studentDocSnap) {
                      if (studentDocSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: LoadingView(message: 'Loading student…'));
                      }
                      if (studentDocSnap.hasError) {
                        return Center(child: Text('Error: ${studentDocSnap.error}'));
                      }

                      final studentData = studentDocSnap.data?.data() ?? const <String, dynamic>{};

                      final classId = ((studentData['class'] as String?) ?? (studentData['classId'] as String?))?.trim();
                      final sectionId = ((studentData['section'] as String?) ?? (studentData['sectionId'] as String?))?.trim();
                      final groupId = ((studentData['group'] as String?) ?? (studentData['groupId'] as String?))?.trim();

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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('student-${_selectedStudentId ?? ''}'),
                                    initialValue: _selectedStudentId,
                                    decoration: InputDecoration(
                                      labelText: 'Student',
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
                                      prefixIcon: const Icon(Icons.badge_outlined),
                                    ),
                                    items: [
                                      for (final c in children)
                                        DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.fullName),
                                        ),
                                    ],
                                    onChanged: (id) => setState(() => _selectedStudentId = id),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Group/Class/Section',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                        ),
                                        Text(
                                          '${groupId ?? '—'} • ${classId ?? '—'}-${sectionId ?? '—'}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: (classId == null || classId.isEmpty || sectionId == null || sectionId.isEmpty || groupId == null || groupId.isEmpty)
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.info_outline, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Incomplete Profile',
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'This student does not have group, class, and section set.',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : _ParentTimetableBody(
                                    yearId: yearId,
                                    groupId: groupId,
                                    classId: classId,
                                    sectionId: sectionId,
                                  ),
                          ),
                        ],
                      );
                    },
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

class _ParentTimetableBody extends ConsumerWidget {
  const _ParentTimetableBody({
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
