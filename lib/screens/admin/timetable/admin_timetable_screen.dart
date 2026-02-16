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

  void _resetEdits() {
    setState(() {
      _dirty = false;
      _editedDays = parseDays(null);
    });
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Timetable',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'Year: $yearId',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: (!_dirty || _saving) ? null : _resetEdits,
                    icon: const Icon(Icons.restart_alt_outlined),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('group-${_groupId ?? ''}'),
                              initialValue: _groupId,
                              decoration: const InputDecoration(
                                labelText: 'Group',
                                prefixIcon: Icon(Icons.groups_2_outlined),
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
                      Text(
                        'Tip: Use the Save button below the tabs after editing periods.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: (_groupId == null || _classId == null || _sectionId == null)
                  ? const Center(child: Text('Pick a Group, Class, and Section above.'))
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
