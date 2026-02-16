import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';

import '../../../widgets/loading_view.dart';

class AdminClassesSectionsScreen extends ConsumerStatefulWidget {
  const AdminClassesSectionsScreen({super.key});

  @override
  ConsumerState<AdminClassesSectionsScreen> createState() =>
      _AdminClassesSectionsScreenState();
}

class _AdminClassesSectionsScreenState
    extends ConsumerState<AdminClassesSectionsScreen> {
  bool _savingYear = false;

  Future<void> _setActiveYearDialog(String current) async {
    final controller = TextEditingController(text: current);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Active Academic Year'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Year ID (example: 2025-26)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final yearId = controller.text.trim();
    if (yearId.isEmpty) return;

    setState(() => _savingYear = true);
    try {
      await ref.read(adminDataServiceProvider).setActiveAcademicYearId(yearId: yearId);
    } finally {
      if (mounted) setState(() => _savingYear = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Center(child: Text('Please login again.'));
    }

    final settingsStream = ref.read(adminDataServiceProvider).watchAppSettings();
    final classesStream = ref.read(adminDataServiceProvider).watchClasses();
    final sectionsStream = ref.read(adminDataServiceProvider).watchSections();

    return StreamBuilder(
      stream: settingsStream,
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data?.data() ?? const <String, Object?>{};
        final yearId = (settings['activeAcademicYearId'] as String?) ?? '2025-26';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Academic Year',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(yearId),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _savingYear ? null : () => _setActiveYearDialog(yearId),
                      child: _savingYear
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Change'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Classes',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            StreamBuilder(
              stream: classesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading classes…');
                }
                final docs = snapshot.data?.docs ?? const [];
                return Column(
                  children: [
                    for (final doc in docs)
                      Card(
                        child: ListTile(
                          title: Text((doc.data()['name'] as String?) ?? doc.id),
                          subtitle: Text('ID: ${doc.id}'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _upsertClassDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add/Update Class'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Sections',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            StreamBuilder(
              stream: sectionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(message: 'Loading sections…');
                }
                final docs = snapshot.data?.docs ?? const [];
                return Column(
                  children: [
                    for (final doc in docs)
                      Card(
                        child: ListTile(
                          title: Text((doc.data()['name'] as String?) ?? doc.id),
                          subtitle: Text('ID: ${doc.id}'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _upsertSectionDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add/Update Section'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Year Class/Sections ($yearId)',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _YearClassSectionsBlock(yearId: yearId),
          ],
        );
      },
    );
  }

  Future<void> _upsertClassDialog() async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final orderController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add/Update Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Class ID (example: class5)'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name (example: Class 5)'),
              ),
              TextField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort order (example: 5)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final classId = idController.text.trim();
    final name = nameController.text.trim();
    final sortOrder = int.tryParse(orderController.text.trim()) ?? 0;
    if (classId.isEmpty || name.isEmpty) return;

    await ref.read(adminDataServiceProvider).upsertClass(
          classId: classId,
          name: name,
          sortOrder: sortOrder,
        );
  }

  Future<void> _upsertSectionDialog() async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final orderController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add/Update Section'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Section ID (example: A)'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name (example: A)'),
              ),
              TextField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort order (example: 1)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final sectionId = idController.text.trim();
    final name = nameController.text.trim();
    final sortOrder = int.tryParse(orderController.text.trim()) ?? 0;
    if (sectionId.isEmpty || name.isEmpty) return;

    await ref.read(adminDataServiceProvider).upsertSection(
          sectionId: sectionId,
          name: name,
          sortOrder: sortOrder,
        );
  }
}

class _YearClassSectionsBlock extends ConsumerWidget {
  const _YearClassSectionsBlock({required this.yearId});

  final String yearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.read(adminDataServiceProvider).watchYearClassSections(yearId: yearId);

    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading year class/sections…');
        }
        final docs = snapshot.data?.docs ?? const [];

        return Column(
          children: [
            for (final doc in docs)
              Card(
                child: ListTile(
                  title: Text((doc.data()['label'] as String?) ?? doc.id),
                  subtitle: Text('ID: ${doc.id}'),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _createYearClassSectionDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Year Class/Section'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createYearClassSectionDialog(BuildContext context, WidgetRef ref) async {
    final classIdController = TextEditingController();
    final sectionIdController = TextEditingController();
    final labelController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Year Class/Section'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: classIdController,
                decoration: const InputDecoration(labelText: 'Class ID (example: class5)'),
              ),
              TextField(
                controller: sectionIdController,
                decoration: const InputDecoration(labelText: 'Section ID (example: A)'),
              ),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label (example: Class 5 - A)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final classId = classIdController.text.trim();
    final sectionId = sectionIdController.text.trim();
    final label = labelController.text.trim();

    if (classId.isEmpty || sectionId.isEmpty || label.isEmpty) return;

    await ref.read(adminDataServiceProvider).upsertYearClassSection(
          yearId: yearId,
          classId: classId,
          sectionId: sectionId,
          label: label,
        );
  }
}
