import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/timetable_service.dart';
import '../../../widgets/loading_view.dart';
import '../../shared/timetable/timetable_widgets.dart';

class AdminTimetableScreen extends ConsumerStatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  ConsumerState<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends ConsumerState<AdminTimetableScreen> {
  static const _groups = <String>['primary', 'middle', 'highschool'];

  String? _groupId;
  String? _classId;
  String? _sectionId;

  bool _saving = false;
  bool _dirty = false;

  Map<String, List<TimetablePeriod>> _editedDays = parseDays(null);

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save({required String yearId, required Map<String, List<TimetablePeriod>> days}) async {
    if (_groupId == null || _classId == null || _sectionId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(timetableServiceProvider).upsertTimetable(
            yearId: yearId,
            groupId: _groupId!,
            classId: _classId!,
            sectionId: _sectionId!,
            days: serializeDays(days),
          );

      if (!mounted) return;
      setState(() => _dirty = false);
      _snack('Timetable saved');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Center(child: Text('Please login again.'));
    }

    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final adminData = ref.read(adminDataServiceProvider);

    final classesStream = adminData.watchClasses();
    final sectionsStream = adminData.watchSections();

    return yearAsync.when(
      loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (yearId) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Timetable'),
            elevation: 0,
          ),
          body: Column(
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
              // Selection Card with Modern Styling
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
                      Text(
                        'Select Group, Class & Section',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('group-${_groupId ?? ''}'),
                              initialValue: _groupId,
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
                                for (final g in _groups)
                                  DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _groupId = v;
                                  _dirty = false;
                                  _editedDays = parseDays(null);
                                });
                              },
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
                                  onChanged: (v) {
                                    setState(() {
                                      _classId = v;
                                      _dirty = false;
                                      _editedDays = parseDays(null);
                                    });
                                  },
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
                                  onChanged: (v) {
                                    setState(() {
                                      _sectionId = v;
                                      _dirty = false;
                                      _editedDays = parseDays(null);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Tip: Use the Save button below the tabs after editing periods.',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
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
                                'Pick a group, class, and section to edit.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _TimetableEditorBody(
                        yearId: yearId,
                        groupId: _groupId!,
                        classId: _classId!,
                        sectionId: _sectionId!,
                        dirty: _dirty,
                        editedDays: _editedDays,
                        saving: _saving,
                        onEdit: (nextDays) {
                          setState(() {
                            _dirty = true;
                            _editedDays = nextDays;
                          });
                        },
                        onSave: (serverDays) {
                          final toSave = _dirty ? _editedDays : serverDays;
                          return _save(yearId: yearId, days: toSave);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimetableEditorBody extends ConsumerWidget {
  const _TimetableEditorBody({
    required this.yearId,
    required this.groupId,
    required this.classId,
    required this.sectionId,
    required this.dirty,
    required this.editedDays,
    required this.saving,
    required this.onEdit,
    required this.onSave,
  });

  final String yearId;
  final String groupId;
  final String classId;
  final String sectionId;
  final bool dirty;
  final Map<String, List<TimetablePeriod>> editedDays;
  final bool saving;
  final ValueChanged<Map<String, List<TimetablePeriod>>> onEdit;
  final Future<void> Function(Map<String, List<TimetablePeriod>> serverDays) onSave;

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
        final serverDays = parseDays(data['days']);
        final displayDays = dirty ? editedDays : serverDays;

        return DefaultTabController(
          length: TimetableDays.keys.length,
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: ListTile(
                  title: Text(
                    '$groupId • $classId-$sectionId',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(dirty ? 'Unsaved changes' : 'Up to date'),
                  trailing: FilledButton.icon(
                    onPressed: saving ? null : () => onSave(serverDays),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving…' : 'Save'),
                  ),
                ),
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
                      TimetableDayEditor(
                        dayKey: dayKey,
                        items: displayDays[dayKey] ?? const <TimetablePeriod>[],
                        onChanged: (nextItems) {
                          final nextDays = Map<String, List<TimetablePeriod>>.from(displayDays);
                          nextDays[dayKey] = nextItems;
                          onEdit(nextDays);
                        },
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
