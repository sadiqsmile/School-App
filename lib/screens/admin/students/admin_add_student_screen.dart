import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminAddStudentScreen extends ConsumerStatefulWidget {
  const AdminAddStudentScreen({super.key});

  @override
  ConsumerState<AdminAddStudentScreen> createState() => _AdminAddStudentScreenState();
}

class _AdminAddStudentScreenState extends ConsumerState<AdminAddStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _admissionController = TextEditingController();
  final _nameController = TextEditingController();
  final _parentMobileController = TextEditingController();
  final _parentNameController = TextEditingController();

  String? _classId;
  String? _sectionId;
  String? _groupId;
  bool _active = true;
  bool _saving = false;

  static const _groups = <String>['primary', 'middle', 'highschool'];

  @override
  void dispose() {
    _admissionController.dispose();
    _nameController.dispose();
    _parentMobileController.dispose();
    _parentNameController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final groupId = _groupId;
    final classId = _classId;
    final sectionId = _sectionId;
    if (groupId == null || classId == null || sectionId == null) {
      _snack('Please select group, class and section');
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await ref.read(adminDataServiceProvider).createStudentAndLinkParent(
            admissionNo: _admissionController.text,
            fullName: _nameController.text,
            groupId: groupId,
            classId: classId,
            sectionId: sectionId,
            parentMobile: _parentMobileController.text,
            parentDisplayName:
                _parentNameController.text.trim().isEmpty ? null : _parentNameController.text,
            isActive: _active,
          );

      if (!mounted) return;
      _snack('Student created (ID: $id)');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesStream = ref.read(adminDataServiceProvider).watchClasses();
    final sectionsStream = ref.read(adminDataServiceProvider).watchSections();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student'),
      ),
      body: _saving
          ? const Center(child: LoadingView(message: 'Saving…'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Student Details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _admissionController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Admission No',
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                            ),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) return 'Admission No is required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Student Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) return 'Student name is required';
                              if ((v ?? '').trim().length < 2) return 'Name is too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey(_groupId),
                            initialValue: _groupId,
                            items: [
                              for (final g in _groups)
                                DropdownMenuItem(
                                  value: g,
                                  child: Text(g[0].toUpperCase() + g.substring(1)),
                                ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Group',
                              prefixIcon: Icon(Icons.account_tree_outlined),
                            ),
                            onChanged: (v) => setState(() => _groupId = v),
                            validator: (v) => (v == null || v.isEmpty) ? 'Select group' : null,
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder(
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
                              final items = docs
                                  .map(
                                    (d) => DropdownMenuItem<String>(
                                      value: d.id,
                                      child: Text((d.data()['name'] as String?) ?? d.id),
                                    ),
                                  )
                                  .toList();

                              return DropdownButtonFormField<String>(
                                key: ValueKey(selected),
                                initialValue: selected,
                                items: items,
                                decoration: const InputDecoration(
                                  labelText: 'Class',
                                  prefixIcon: Icon(Icons.class_outlined),
                                ),
                                onChanged: (v) => setState(() => _classId = v),
                                validator: (v) => (v == null || v.isEmpty) ? 'Select class' : null,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder(
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
                              final items = docs
                                  .map(
                                    (d) => DropdownMenuItem<String>(
                                      value: d.id,
                                      child: Text((d.data()['name'] as String?) ?? d.id),
                                    ),
                                  )
                                  .toList();

                              return DropdownButtonFormField<String>(
                                key: ValueKey(selected),
                                initialValue: selected,
                                items: items,
                                decoration: const InputDecoration(
                                  labelText: 'Section',
                                  prefixIcon: Icon(Icons.group_outlined),
                                ),
                                onChanged: (v) => setState(() => _sectionId = v),
                                validator: (v) => (v == null || v.isEmpty) ? 'Select section' : null,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _parentMobileController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Parent Mobile (10 digits)',
                              prefixIcon: Icon(Icons.phone_android_outlined),
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Parent mobile is required';
                              if (t.length != 10) return 'Mobile must be exactly 10 digits';
                              if (int.tryParse(t) == null) return 'Mobile must contain only digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _parentNameController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Parent Name (optional)',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _active,
                            onChanged: (v) => setState(() => _active = v),
                            title: const Text('Active'),
                            subtitle: const Text('Inactive students can be hidden from lists.'),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save Student'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Note: Admission No must be unique. If parent does not exist, it will be created with password = last 4 digits.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
