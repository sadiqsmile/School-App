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
        loading: () => const Center(child: LoadingView(message: 'Loading…')),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (yearId) {
          return StreamBuilder<List<String>>(
            stream: assignedStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingView(message: 'Loading…'));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final classSectionIds = snapshot.data ?? const [];
              if (classSectionIds.isEmpty) {
                return SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No Classes Assigned',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask your admin to assign classes to your account.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    children: [
                      // Premium Gradient Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.assignment_sharp, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mark Attendance',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                      ),
                                      Text(
                                        'Academic Year: $yearId',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Class & Section Selection Card
                      _buildModernCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Class & Section',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            // Class Dropdown
                            _buildModernDropdown(
                              context,
                              label: 'Class',
                              value: _selectedClassId,
                              items: classIds,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _selectedClassId = v;
                                  final nextSections = (byClass[v] ?? const <String>{}).toList()..sort();
                                  _selectedSectionId = nextSections.isEmpty ? null : nextSections.first;
                                });
                              },
                              icon: Icons.class_outlined,
                            ),
                            const SizedBox(height: 12),
                            // Section Dropdown
                            _buildModernDropdown(
                              context,
                              label: 'Section',
                              value: _selectedSectionId,
                              items: sectionIds,
                              onChanged: (v) => setState(() => _selectedSectionId = v),
                              icon: Icons.group_outlined,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Assigned: ${pairs.length} class-sections',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick Pick Dropdown
                      _buildModernCard(
                        context,
                        child: _buildModernDropdown(
                          context,
                          label: 'Quick Pick (assigned pairs)',
                          value: _selectedClassId == null || _selectedSectionId == null
                              ? null
                              : '${_selectedClassId}_${_selectedSectionId}',
                          items: [
                            for (final p in pairs)
                              '${p.classId}_${p.sectionId}',
                          ],
                          itemLabels: [
                            for (final p in pairs)
                              '${p.classId} • ${p.sectionId}',
                          ],
                          onChanged: (v) {
                            final parsed = v == null ? null : _parseClassSection(v);
                            if (parsed == null) return;
                            setState(() {
                              _selectedClassId = parsed.classId;
                              _selectedSectionId = parsed.sectionId;
                            });
                          },
                          icon: Icons.task_alt_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date Selection Card
                      _buildModernCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Date',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                                    Icon(Icons.expand_more, color: Theme.of(context).colorScheme.outline, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
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
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernCard(BuildContext context, {required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  Widget _buildModernDropdown(
    BuildContext context, {
    required String label,
    required String? value,
    required List<String> items,
    List<String>? itemLabels,
    required Function(String?) onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      items: [
        for (int i = 0; i < items.length; i++)
          DropdownMenuItem(
            value: items[i],
            child: Text(itemLabels?[i] ?? items[i]),
          ),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
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
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }
}
