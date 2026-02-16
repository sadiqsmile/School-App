import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import 'teacher_mark_attendance_screen.dart';

class TeacherAttendanceSetupScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceSetupScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceSetupScreen> createState() =>
      _TeacherAttendanceSetupScreenState();
}

class _TeacherAttendanceSetupScreenState
    extends ConsumerState<TeacherAttendanceSetupScreen> {
  String? _selectedClassId;
  String? _selectedSectionId;
  DateTime _selectedDate = DateTime.now();

  ({String classId, String sectionId})? _parseClassSection(String id) {
    final parts = id.split('_');
    if (parts.length != 2) return null;
    final classId = parts[0].trim();
    final sectionId = parts[1].trim();
    if (classId.isEmpty || sectionId.isEmpty) return null;
    return (classId: classId, sectionId: sectionId);
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mark Attendance')),
        body: const Center(child: Text('Please login again.')),
      );
    }

    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final assignedStream = ref
        .read(teacherDataServiceProvider)
        .watchAssignedClassSectionIds(teacherUid: authUser.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: yearAsync.when(
        loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (yearId) {
          return StreamBuilder<List<String>>(
            stream: assignedStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingView(message: 'Loading assignments…'));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final classSectionIds = snapshot.data ?? const [];
              if (classSectionIds.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No class/section assigned to this teacher yet.\n\nAsk admin to set teacherAssignments for your account.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final pairs = <({String classId, String sectionId})>[];
              for (final id in classSectionIds) {
                final parsed = _parseClassSection(id);
                if (parsed != null) pairs.add(parsed);
              }

              if (pairs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Teacher assignments are present, but classSectionIds are not in the expected format (classId_sectionId).\n\nAsk admin to fix teacherAssignments.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final byClass = <String, Set<String>>{};
              for (final p in pairs) {
                (byClass[p.classId] ??= <String>{}).add(p.sectionId);
              }

              final classIds = byClass.keys.toList()..sort();

              // Ensure current selection remains valid.
              if (_selectedClassId == null || !byClass.containsKey(_selectedClassId)) {
                _selectedClassId = pairs.first.classId;
              }

              final sectionIds = (byClass[_selectedClassId] ?? const <String>{}).toList()..sort();
              if (_selectedSectionId == null || !sectionIds.contains(_selectedSectionId)) {
                _selectedSectionId = sectionIds.first;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Year: $yearId',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(_selectedClassId),
                                  initialValue: _selectedClassId,
                                  items: [
                                    for (final id in classIds)
                                      DropdownMenuItem(
                                        value: id,
                                        child: Text(id),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _selectedClassId = v;
                                      final nextSections = (byClass[v] ?? const <String>{}).toList()..sort();
                                      _selectedSectionId = nextSections.isEmpty ? null : nextSections.first;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Class',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.class_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(_selectedSectionId),
                                  initialValue: _selectedSectionId,
                                  items: [
                                    for (final id in sectionIds)
                                      DropdownMenuItem(
                                        value: id,
                                        child: Text(id),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() => _selectedSectionId = v),
                                  decoration: const InputDecoration(
                                    labelText: 'Section',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.group_outlined),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Assigned: ${pairs.length} class-sections',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('$_selectedClassId-$_selectedSectionId'),
                            initialValue: _selectedClassId == null || _selectedSectionId == null
                                ? null
                                : '$_selectedClassId-$_selectedSectionId',
                            items: [
                              for (final p in pairs)
                                DropdownMenuItem(
                                  value: '${p.classId}_${p.sectionId}',
                                  child: Text('${p.classId} • ${p.sectionId}'),
                                ),
                            ],
                            onChanged: (v) {
                              final parsed = v == null ? null : _parseClassSection(v);
                              if (parsed == null) return;
                              setState(() {
                                _selectedClassId = parsed.classId;
                                _selectedSectionId = parsed.sectionId;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Quick pick (assigned pairs)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2020, 1, 1),
                                lastDate: DateTime(2035, 12, 31),
                                initialDate: _selectedDate,
                              );
                              if (picked != null) {
                                setState(() => _selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                                  const Icon(Icons.date_range),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: (_selectedClassId == null || _selectedSectionId == null)
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TeacherMarkAttendanceScreen(
                                    yearId: yearId,
                                    classId: _selectedClassId!,
                                    sectionId: _selectedSectionId!,
                                    date: _selectedDate,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.checklist),
                      label: const Text('Open Student List'),
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
