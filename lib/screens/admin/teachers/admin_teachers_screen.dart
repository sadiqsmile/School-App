import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import '../../../features/csv/teacher_assignments_csv.dart';
import '../../../utils/csv_saver.dart';
import 'admin_teacher_assignments_csv_import_screen.dart';

enum _TeacherCsvAction {
  export,
  import,
}

class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  ConsumerState<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends ConsumerState<AdminTeachersScreen> {
  bool _creating = false;
  bool _assigning = false;

  static const _groups = <String>['primary', 'middle', 'highschool'];

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportTeacherAssignmentsCsv() async {
    try {
      final rows = await ref.read(teacherAssignmentCsvImportServiceProvider)
          .exportTeacherAssignmentsForCsv();
      final csvText = buildTeacherAssignmentsCsv(assignments: rows);

      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final fileName = 'teacher_assignments_$y$m$d.csv';

      await saveCsvText(fileName: fileName, csvText: csvText);

      if (!mounted) return;
      _snack('CSV exported');
    } catch (e) {
      if (!mounted) return;
      _snack('Export failed: $e');
    }
  }

  Future<void> _importTeacherAssignmentsCsv() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        _snack('Could not read the selected file. Please try again.');
        return;
      }

      final parsed = parseTeacherAssignmentsCsvBytes(bytes: bytes);
      if (!mounted) return;
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AdminTeacherAssignmentsCsvImportScreen(parseResult: parsed),
        ),
      );
      if (!mounted) return;
      if (ok == true) _snack('Import complete');
    } catch (e) {
      if (!mounted) return;
      _snack('Import failed: $e');
    }
  }

  Future<void> _createTeacherDialog() async {
    final uidController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final selectedGroups = <String>{};

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Teacher Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: uidController,
                  decoration: const InputDecoration(
                    labelText: 'Teacher UID (from Firebase Auth)',
                    hintText: 'Copy UID from Firebase Console → Authentication → Users',
                  ),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Teacher name'),
                ),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Assigned Groups (required)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                for (final g in _groups)
                  StatefulBuilder(
                    builder: (context, setLocal) {
                      final checked = selectedGroups.contains(g);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: checked,
                        title: Text(g[0].toUpperCase() + g.substring(1)),
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) {
                              selectedGroups.add(g);
                            } else {
                              selectedGroups.remove(g);
                            }
                          });
                        },
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Text(
                  'Free plan note: This app cannot create Firebase Auth users.\n'
                  'Create the teacher in Firebase Auth (Console) first, then paste the UID here to create their profile.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        );
      },
    );

    if (ok != true) return;

    final teacherUid = uidController.text.trim();
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (teacherUid.isEmpty || name.isEmpty || email.isEmpty) return;
    if (selectedGroups.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one assigned group.')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      await ref.read(adminServiceProvider).createTeacherProfile(
            teacherUid: teacherUid,
            email: email,
            displayName: name,
            phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        assignedGroups: selectedGroups.toList()..sort(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teacher profile saved for UID: $teacherUid')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _assignTeacherDialog({required String teacherUid}) async {
    final yearId = await ref.read(activeAcademicYearIdProvider.future);
    if (!mounted) return;

    final classSectionsStream = ref.read(adminDataServiceProvider).watchYearClassSections(yearId: yearId);

    final selected = <String>{};

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign Classes/Sections'),
          content: SizedBox(
            width: 420,
            child: StreamBuilder(
              stream: classSectionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading class/sections…');
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Text('No year class/sections yet. Create them in Classes/Sections.');
                }

                return ListView(
                  shrinkWrap: true,
                  children: [
                    Text('Year: $yearId'),
                    const SizedBox(height: 8),
                    for (final doc in docs)
                      StatefulBuilder(
                        builder: (context, setLocal) {
                          final id = doc.id;
                          final label = (doc.data()['label'] as String?) ?? id;
                          final checked = selected.contains(id);
                          return CheckboxListTile(
                            value: checked,
                            title: Text(label),
                            subtitle: Text(id),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  selected.add(id);
                                } else {
                                  selected.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() => _assigning = true);
    try {
      await ref.read(adminDataServiceProvider).setTeacherAssignments(
            teacherUid: teacherUid,
            classSectionIds: selected.toList()..sort(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher assignments saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachersStream = ref.read(adminDataServiceProvider).watchTeachers();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Teachers',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<_TeacherCsvAction>(
                tooltip: 'CSV actions',
                onSelected: (action) {
                  switch (action) {
                    case _TeacherCsvAction.export:
                      _exportTeacherAssignmentsCsv();
                      break;
                    case _TeacherCsvAction.import:
                      _importTeacherAssignmentsCsv();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _TeacherCsvAction.export,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.download_outlined),
                      title: Text('Export Assignments'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _TeacherCsvAction.import,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.upload_file_outlined),
                      title: Text('Import Assignments'),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _creating ? null : _createTeacherDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: teachersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingView(message: 'Loading teachers…'));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return const Center(child: Text('No teachers yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final name = (data['displayName'] as String?) ?? 'Teacher';
                  final email = (data['email'] as String?) ?? '-';

                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: _assigning ? null : () => _assignTeacherDialog(teacherUid: doc.id),
                            child: const Text('Assign'),
                          ),
                          Text(doc.id, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
