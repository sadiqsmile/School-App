import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

import 'admin_add_student_screen.dart';
import 'admin_student_details_screen.dart';

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  String _search = '';
  String? _classId;
  String? _sectionId;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddStudent() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminAddStudentScreen()),
    );
    if (!mounted) return;
    if (ok == true) _snack('Student saved');
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Center(child: Text('Please login again.'));
    }

    final service = ref.read(adminDataServiceProvider);
    final studentsStream = service.watchBaseStudents();
    final classesStream = service.watchClasses();
    final sectionsStream = service.watchSections();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Students',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                onPressed: _openAddStudent,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search by name or admission no',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder(
                      stream: classesStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final docs = snap.data?.docs ?? const [];
                        final ids = docs.map((d) => d.id).toSet();
                        final selected = (_classId != null && ids.contains(_classId)) ? _classId : null;

                        final items = <DropdownMenuItem<String?>>[
                          const DropdownMenuItem(value: null, child: Text('All classes')),
                          for (final d in docs)
                            DropdownMenuItem(
                              value: d.id,
                              child: Text((d.data()['name'] as String?) ?? d.id),
                            ),
                        ];

                        return DropdownButtonFormField<String?>(
                          key: ValueKey(selected),
                          initialValue: selected,
                          items: items,
                          onChanged: (v) => setState(() => _classId = v),
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            prefixIcon: Icon(Icons.class_outlined),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StreamBuilder(
                      stream: sectionsStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final docs = snap.data?.docs ?? const [];
                        final ids = docs.map((d) => d.id).toSet();
                        final selected = (_sectionId != null && ids.contains(_sectionId)) ? _sectionId : null;

                        final items = <DropdownMenuItem<String?>>[
                          const DropdownMenuItem(value: null, child: Text('All sections')),
                          for (final d in docs)
                            DropdownMenuItem(
                              value: d.id,
                              child: Text((d.data()['name'] as String?) ?? d.id),
                            ),
                        ];

                        return DropdownButtonFormField<String?>(
                          key: ValueKey(selected),
                          initialValue: selected,
                          items: items,
                          onChanged: (v) => setState(() => _sectionId = v),
                          decoration: const InputDecoration(
                            labelText: 'Section',
                            prefixIcon: Icon(Icons.group_outlined),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: studentsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingView(message: 'Loading students…'));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return const Center(child: Text('No students yet.'));
              }

              final q = _search.trim().toLowerCase();
              final filtered = docs.where((d) {
                final data = d.data();
                final name = (((data['name'] as String?) ?? (data['fullName'] as String?) ?? '')).toLowerCase();
                final admission = ((data['admissionNo'] as String?) ?? '').toLowerCase();
                final classId = (data['class'] as String?) ?? (data['classId'] as String?) ?? '';
                final sectionId = (data['section'] as String?) ?? (data['sectionId'] as String?) ?? '';

                final matchesSearch = q.isEmpty || name.contains(q) || admission.contains(q);
                final matchesClass = _classId == null || classId == _classId;
                final matchesSection = _sectionId == null || sectionId == _sectionId;
                return matchesSearch && matchesClass && matchesSection;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No students found.'));
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total: ${filtered.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();

                        final name = (data['name'] as String?) ?? (data['fullName'] as String?) ?? 'Student';
                        final admission = (data['admissionNo'] as String?) ?? '-';
                        final classId = (data['class'] as String?) ?? (data['classId'] as String?) ?? '-';
                        final sectionId = (data['section'] as String?) ?? (data['sectionId'] as String?) ?? '-';
                        final parentMobile = (data['parentMobile'] as String?) ?? '-';
                        final active = (data['isActive'] ?? true) == true;

                        return Card(
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text(
                              'Admission: $admission\nClass/Section: $classId-$sectionId\nParent: $parentMobile',
                            ),
                            isThreeLine: true,
                            trailing: active
                                ? const Icon(Icons.check_circle_outline, color: Colors.green)
                                : const Icon(Icons.pause_circle_outline, color: Colors.orange),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminStudentDetailsScreen(studentId: doc.id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

}
