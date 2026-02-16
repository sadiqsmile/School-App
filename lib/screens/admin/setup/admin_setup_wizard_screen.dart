import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminSetupWizardScreen extends ConsumerStatefulWidget {
  const AdminSetupWizardScreen({super.key});

  @override
  ConsumerState<AdminSetupWizardScreen> createState() => _AdminSetupWizardScreenState();
}

class _AdminSetupWizardScreenState extends ConsumerState<AdminSetupWizardScreen> {
  int _step = 0;

  final _yearController = TextEditingController();

  final _classIdController = TextEditingController(text: 'class1');
  final _classNameController = TextEditingController(text: 'Class 1');
  final _classOrderController = TextEditingController(text: '1');

  final _sectionIdController = TextEditingController(text: 'A');
  final _sectionNameController = TextEditingController(text: 'A');
  final _sectionOrderController = TextEditingController(text: '1');

  final _ycsClassIdController = TextEditingController(text: 'class1');
  final _ycsSectionIdController = TextEditingController(text: 'A');
  final _ycsLabelController = TextEditingController(text: 'Class 1 - A');

  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();

  final _teacherUidController = TextEditingController();
  final _teacherNameController = TextEditingController();
  final _teacherEmailController = TextEditingController();

  final _studentNameController = TextEditingController();
  final _studentAdmissionController = TextEditingController();

  String? _selectedTeacherUid;
  final Set<String> _selectedTeacherClassSections = <String>{};

  String? _selectedStudentId;
  String? _selectedStudentClassSectionId;
  final _studentRollNoController = TextEditingController();
  final _studentParentUidsController = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _yearController.dispose();

    _classIdController.dispose();
    _classNameController.dispose();
    _classOrderController.dispose();

    _sectionIdController.dispose();
    _sectionNameController.dispose();
    _sectionOrderController.dispose();

    _ycsClassIdController.dispose();
    _ycsSectionIdController.dispose();
    _ycsLabelController.dispose();

    _parentNameController.dispose();
    _parentPhoneController.dispose();

    _teacherUidController.dispose();
    _teacherNameController.dispose();
    _teacherEmailController.dispose();

    _studentNameController.dispose();
    _studentAdmissionController.dispose();

    _studentRollNoController.dispose();
    _studentParentUidsController.dispose();

    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _guard(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
        if (settingsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingView(message: 'Loading settings…'));
        }

        final settings = settingsSnap.data?.data() ?? const <String, Object?>{};
        final yearId = (settings['activeAcademicYearId'] as String?) ?? '2025-26';
        _yearController.text = yearId;

        final yearClassSectionsStream =
            ref.read(adminDataServiceProvider).watchYearClassSections(yearId: yearId);
        final teachersStream = ref.read(adminDataServiceProvider).watchTeachers();
        final studentsStream = ref.read(adminDataServiceProvider).watchStudents();

        return Stepper(
          currentStep: _step,
          onStepContinue: _busy
              ? null
              : () {
                  if (_step < 4) setState(() => _step++);
                },
          onStepCancel: _busy
              ? null
              : () {
                  if (_step > 0) setState(() => _step--);
                },
          steps: [
            Step(
              title: const Text('1) Set Academic Year'),
              isActive: _step >= 0,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current active year: $yearId'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _yearController,
                    decoration: const InputDecoration(
                      labelText: 'Academic year ID',
                      hintText: 'example: 2025-26',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final newYear = _yearController.text.trim();
                              if (newYear.isEmpty) return;
                              await ref
                                  .read(adminDataServiceProvider)
                                  .setActiveAcademicYearId(yearId: newYear);
                              _snack('Active year saved');
                            }),
                    child: const Text('Save Year'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything else (class sections, attendance, marks) will be saved under this year.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('2) Create Classes & Sections'),
              isActive: _step >= 1,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add at least one class and one section.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Class', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _classIdController,
                    decoration: const InputDecoration(labelText: 'Class ID (example: class5)'),
                  ),
                  TextField(
                    controller: _classNameController,
                    decoration: const InputDecoration(labelText: 'Class name (example: Class 5)'),
                  ),
                  TextField(
                    controller: _classOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sort order'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final id = _classIdController.text.trim();
                              final name = _classNameController.text.trim();
                              final order = int.tryParse(_classOrderController.text.trim()) ?? 0;
                              if (id.isEmpty || name.isEmpty) return;
                              await ref
                                  .read(adminDataServiceProvider)
                                  .upsertClass(classId: id, name: name, sortOrder: order);
                              _snack('Class saved');
                            }),
                    child: const Text('Save Class'),
                  ),
                  const SizedBox(height: 16),
                  Text('Section', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sectionIdController,
                    decoration: const InputDecoration(labelText: 'Section ID (example: A)'),
                  ),
                  TextField(
                    controller: _sectionNameController,
                    decoration: const InputDecoration(labelText: 'Section name (example: A)'),
                  ),
                  TextField(
                    controller: _sectionOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sort order'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final id = _sectionIdController.text.trim();
                              final name = _sectionNameController.text.trim();
                              final order = int.tryParse(_sectionOrderController.text.trim()) ?? 0;
                              if (id.isEmpty || name.isEmpty) return;
                              await ref
                                  .read(adminDataServiceProvider)
                                  .upsertSection(sectionId: id, name: name, sortOrder: order);
                              _snack('Section saved');
                            }),
                    child: const Text('Save Section'),
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('View existing classes/sections'),
                    children: [
                      StreamBuilder(
                        stream: classesStream,
                        builder: (context, snap) {
                          final docs = snap.data?.docs ?? const [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text('Classes:'),
                              ),
                              for (final d in docs)
                                ListTile(
                                  dense: true,
                                  title: Text((d.data()['name'] as String?) ?? d.id),
                                  subtitle: Text(d.id),
                                ),
                            ],
                          );
                        },
                      ),
                      StreamBuilder(
                        stream: sectionsStream,
                        builder: (context, snap) {
                          final docs = snap.data?.docs ?? const [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text('Sections:'),
                              ),
                              for (final d in docs)
                                ListTile(
                                  dense: true,
                                  title: Text((d.data()['name'] as String?) ?? d.id),
                                  subtitle: Text(d.id),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('3) Create Year Class/Sections'),
              isActive: _step >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Year Class/Section is what Teachers get assigned to and where Students belong.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ycsClassIdController,
                    decoration: const InputDecoration(labelText: 'Class ID (example: class5)'),
                  ),
                  TextField(
                    controller: _ycsSectionIdController,
                    decoration: const InputDecoration(labelText: 'Section ID (example: A)'),
                  ),
                  TextField(
                    controller: _ycsLabelController,
                    decoration: const InputDecoration(labelText: 'Label (example: Class 5 - A)'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final c = _ycsClassIdController.text.trim();
                              final s = _ycsSectionIdController.text.trim();
                              final label = _ycsLabelController.text.trim();
                              if (c.isEmpty || s.isEmpty || label.isEmpty) return;
                              await ref.read(adminDataServiceProvider).upsertYearClassSection(
                                    yearId: yearId,
                                    classId: c,
                                    sectionId: s,
                                    label: label,
                                  );
                              _snack('Year class/section saved');
                            }),
                    child: const Text('Save Year Class/Section'),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder(
                    stream: yearClassSectionsStream,
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return const Text('No year class/sections yet.');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Existing:'),
                          for (final d in docs)
                            ListTile(
                              dense: true,
                              title: Text((d.data()['label'] as String?) ?? d.id),
                              subtitle: Text(d.id),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('4) Create Accounts & Students'),
              isActive: _step >= 3,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create at least 1 Parent, 1 Teacher, and 1 Student for testing.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Parent', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _parentNameController,
                    decoration: const InputDecoration(labelText: 'Parent name'),
                  ),
                  TextField(
                    controller: _parentPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Parent mobile'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final name = _parentNameController.text.trim();
                              final phone = _parentPhoneController.text.trim();
                              if (name.isEmpty || phone.isEmpty) return;
                              final res = await ref.read(adminServiceProvider).createParent(
                                    phone: phone,
                                    displayName: name,
                                  );
                              _snack('Parent created: ${res.mobile} (password: ${res.defaultPassword})');
                            }),
                    child: const Text('Create Parent'),
                  ),
                  const SizedBox(height: 16),
                  Text('Teacher', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _teacherUidController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher UID (from Firebase Auth)',
                      hintText: 'Create teacher in Firebase Console first, then paste UID',
                    ),
                  ),
                  TextField(
                    controller: _teacherNameController,
                    decoration: const InputDecoration(labelText: 'Teacher name'),
                  ),
                  TextField(
                    controller: _teacherEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Teacher email'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final teacherUid = _teacherUidController.text.trim();
                              final name = _teacherNameController.text.trim();
                              final email = _teacherEmailController.text.trim();
                              if (teacherUid.isEmpty || name.isEmpty || email.isEmpty) return;
                              await ref.read(adminServiceProvider).createTeacherProfile(
                                    teacherUid: teacherUid,
                                    email: email,
                                    displayName: name,
                                  );
                              _snack('Teacher profile saved: $teacherUid');
                            }),
                    child: const Text('Create Teacher'),
                  ),
                  const SizedBox(height: 16),
                  Text('Student', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _studentNameController,
                    decoration: const InputDecoration(labelText: 'Student full name'),
                  ),
                  TextField(
                    controller: _studentAdmissionController,
                    decoration: const InputDecoration(labelText: 'Admission no (optional)'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final name = _studentNameController.text.trim();
                              if (name.isEmpty) return;
                              await ref.read(adminDataServiceProvider).createStudent(
                                    fullName: name,
                                    admissionNo: _studentAdmissionController.text.trim().isEmpty
                                        ? null
                                        : _studentAdmissionController.text.trim(),
                                  );
                              _snack('Student created');
                            }),
                    child: const Text('Create Student'),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('5) Assign Teacher & Student'),
              isActive: _step >= 4,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assignments make your Teacher attendance + Parent student list work.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Assign Teacher → class/sections',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: teachersStream,
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final items = docs
                          .map((d) => DropdownMenuItem<String>(
                                value: d.id,
                                child: Text((d.data()['displayName'] as String?) ?? d.id),
                              ))
                          .toList();

                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Teacher'),
                        key: ValueKey('teacher-${_selectedTeacherUid ?? ""}'),
                        initialValue: _selectedTeacherUid,
                        items: items,
                        onChanged: _busy
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedTeacherUid = v;
                                });
                              },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: yearClassSectionsStream,
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return const Text('Create Year Class/Sections first.');
                      }
                      return Column(
                        children: [
                          for (final d in docs)
                            CheckboxListTile(
                              value: _selectedTeacherClassSections.contains(d.id),
                              title: Text((d.data()['label'] as String?) ?? d.id),
                              subtitle: Text(d.id),
                              onChanged: _busy
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedTeacherClassSections.add(d.id);
                                        } else {
                                          _selectedTeacherClassSections.remove(d.id);
                                        }
                                      });
                                    },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final teacherUid = _selectedTeacherUid;
                              if (teacherUid == null || teacherUid.isEmpty) return;
                              await ref.read(adminDataServiceProvider).setTeacherAssignments(
                                    teacherUid: teacherUid,
                                    classSectionIds: _selectedTeacherClassSections.toList()..sort(),
                                  );
                              _snack('Teacher assignments saved');
                            }),
                    child: const Text('Save Teacher Assignments'),
                  ),
                  const SizedBox(height: 16),
                  Text('Assign Student → year class/section + parent UIDs',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: studentsStream,
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final items = docs
                          .map((d) => DropdownMenuItem<String>(
                                value: d.id,
                                child: Text((d.data()['fullName'] as String?) ?? d.id),
                              ))
                          .toList();
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Student'),
                        key: ValueKey('student-${_selectedStudentId ?? ""}'),
                        initialValue: _selectedStudentId,
                        items: items,
                        onChanged: _busy
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedStudentId = v;
                                });
                              },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: yearClassSectionsStream,
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final items = docs
                          .map((d) => DropdownMenuItem<String>(
                                value: d.id,
                                child: Text((d.data()['label'] as String?) ?? d.id),
                              ))
                          .toList();
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Year class/section'),
                        key: ValueKey('studentCS-${_selectedStudentClassSectionId ?? ""}'),
                        initialValue: _selectedStudentClassSectionId,
                        items: items,
                        onChanged: _busy
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedStudentClassSectionId = v;
                                });
                              },
                      );
                    },
                  ),
                  TextField(
                    controller: _studentRollNoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Roll no (optional)'),
                  ),
                  TextField(
                    controller: _studentParentUidsController,
                    decoration: const InputDecoration(
                      labelText: 'Parent UIDs (comma separated)',
                      hintText: 'paste the UID shown after creating parent',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _guard(() async {
                              final studentId = _selectedStudentId;
                              final classSectionId = _selectedStudentClassSectionId;
                              if (studentId == null || classSectionId == null) return;
                              final rollNo = int.tryParse(_studentRollNoController.text.trim());
                              final parentUids = _studentParentUidsController.text
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                              await ref.read(adminDataServiceProvider).assignStudentToYear(
                                    yearId: yearId,
                                    studentId: studentId,
                                    classSectionId: classSectionId,
                                    rollNo: rollNo,
                                    parentUids: parentUids,
                                  );
                              _snack('Student assigned to year');
                            }),
                    child: const Text('Save Student Assignment'),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Quick test: Teacher logs in → Mark Attendance for assigned class. Parent logs in → Student list appears → Attendance shows in calendar.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
