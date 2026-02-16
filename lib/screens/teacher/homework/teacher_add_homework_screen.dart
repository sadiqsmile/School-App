import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/homework_service.dart';
import '../../../widgets/loading_view.dart';

class TeacherAddHomeworkScreen extends ConsumerStatefulWidget {
  const TeacherAddHomeworkScreen({super.key});

  @override
  ConsumerState<TeacherAddHomeworkScreen> createState() => _TeacherAddHomeworkScreenState();
}

class _TeacherAddHomeworkScreenState extends ConsumerState<TeacherAddHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _classId;
  String? _sectionId;
  String? _subject;
  String _type = 'homework';
  bool _active = true;
  DateTime _publishDate = DateTime.now();

  final List<PlatformFile> _picked = [];

  bool _saving = false;
  HomeworkUploadProgress? _progress;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<String> _defaultSubjects() {
    return const [
      'English',
      'Mathematics',
      'Science',
      'Social Studies',
      'Computer',
      'Urdu',
      'Islamiyat',
      'General',
    ];
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true, // required for Web; also works on Android
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'gif'],
    );

    if (res == null) return;

    final newFiles = res.files.where((f) => f.bytes != null).toList();
    if (newFiles.isEmpty) {
      _snack('Could not read selected files. Please try again.');
      return;
    }

    setState(() {
      // De-dup by name+size (simple)
      for (final f in newFiles) {
        final exists = _picked.any((x) => x.name == f.name && x.size == f.size);
        if (!exists) _picked.add(f);
      }
    });
  }

  Future<void> _removeFileAt(int index) async {
    setState(() => _picked.removeAt(index));
  }

  Future<void> _save() async {
    final yearId = ref.read(activeAcademicYearIdProvider).asData?.value;
    final uid = ref.read(firebaseAuthUserProvider).asData?.value?.uid;
    final appUser = ref.read(appUserProvider).asData?.value;

    if (yearId == null || yearId.isEmpty) {
      _snack('Active academic year is not set');
      return;
    }
    if (uid == null || uid.isEmpty) {
      _snack('Please login again');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final classId = _classId;
    final sectionId = _sectionId;
    final subject = _subject;

    if (classId == null || sectionId == null) {
      _snack('Please select class and section');
      return;
    }
    if (subject == null || subject.trim().isEmpty) {
      _snack('Please select subject');
      return;
    }

    setState(() {
      _saving = true;
      _progress = const HomeworkUploadProgress(stage: HomeworkUploadStage.preparing);
    });

    try {
      final files = _picked
          .map((f) => HomeworkUploadFile(
                fileName: f.name,
                bytes: f.bytes as Uint8List,
                size: f.size,
              ))
          .toList(growable: false);

      await ref.read(homeworkServiceProvider).createHomeworkWithUploads(
            yearId: yearId,
            title: _titleCtrl.text,
            description: _descCtrl.text,
            classId: classId,
            sectionId: sectionId,
            subject: subject,
            type: _type,
            publishDate: _publishDate,
            createdByUid: uid,
            createdByName: appUser?.displayName ?? 'Teacher',
            isActive: _active,
            files: files,
            onProgress: (p) {
              if (!mounted) return;
              setState(() => _progress = p);
            },
          );

      if (!mounted) return;
      _snack('Saved');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('Save failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesStream = ref.read(adminDataServiceProvider).watchClasses();
    final sectionsStream = ref.read(adminDataServiceProvider).watchSections();

    final subjects = _defaultSubjects();

    final progress = _progress;
    final progressText = switch (progress?.stage) {
      HomeworkUploadStage.preparing => 'Preparing…',
      HomeworkUploadStage.uploading =>
        'Uploading ${((progress?.fileIndex ?? 0) + 1)}/${progress?.fileCount ?? 0}: ${progress?.fileName ?? ''}',
      HomeworkUploadStage.saving => 'Saving…',
      HomeworkUploadStage.done => 'Done',
      _ => null,
    };

    final uploadFrac = (progress?.stage == HomeworkUploadStage.uploading)
        ? (progress?.progress ?? 0)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Homework / Notes')),
      body: _saving
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LoadingView(message: 'Working…'),
                    const SizedBox(height: 12),
                    if (progressText != null) Text(progressText, textAlign: TextAlign.center),
                    if (uploadFrac != null) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(value: uploadFrac),
                    ],
                  ],
                ),
              ),
            )
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
                            'Details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              prefixIcon: Icon(Icons.title),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              prefixIcon: Icon(Icons.notes_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
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

                                    final items = <DropdownMenuItem<String>>[
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text((d.data()['name'] as String?) ?? d.id),
                                        ),
                                    ];

                                    return DropdownButtonFormField<String>(
                                      key: ValueKey(selected),
                                      initialValue: selected,
                                      items: items,
                                      onChanged: (v) => setState(() => _classId = v),
                                      decoration: const InputDecoration(
                                        labelText: 'Class',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.class_outlined),
                                      ),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Select class' : null,
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
                                    final selected =
                                        (_sectionId != null && ids.contains(_sectionId)) ? _sectionId : null;

                                    final items = <DropdownMenuItem<String>>[
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text((d.data()['name'] as String?) ?? d.id),
                                        ),
                                    ];

                                    return DropdownButtonFormField<String>(
                                      key: ValueKey(selected),
                                      initialValue: selected,
                                      items: items,
                                      onChanged: (v) => setState(() => _sectionId = v),
                                      decoration: const InputDecoration(
                                        labelText: 'Section',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.group_outlined),
                                      ),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Select section' : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey(_subject),
                            initialValue: _subject,
                            items: [
                              for (final s in subjects) DropdownMenuItem(value: s, child: Text(s)),
                            ],
                            onChanged: (v) => setState(() => _subject = v),
                            decoration: const InputDecoration(
                              labelText: 'Subject',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Select subject' : null,
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'homework', label: Text('Homework'), icon: Icon(Icons.edit_note)),
                              ButtonSegment(value: 'notes', label: Text('Notes'), icon: Icon(Icons.description_outlined)),
                            ],
                            selected: {_type},
                            onSelectionChanged: (s) => setState(() => _type = s.first),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2020, 1, 1),
                                lastDate: DateTime(2035, 12, 31),
                                initialDate: _publishDate,
                              );
                              if (picked != null) setState(() => _publishDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Publish Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.date_range_outlined),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${_publishDate.year.toString().padLeft(4, '0')}-'
                                      '${_publishDate.month.toString().padLeft(2, '0')}-'
                                      '${_publishDate.day.toString().padLeft(2, '0')}'),
                                  const Icon(Icons.edit_calendar_outlined),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _active,
                            onChanged: (v) => setState(() => _active = v),
                            title: const Text('Active'),
                            subtitle: const Text('Inactive items are hidden from parents.'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Attachments',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Pick files (PDF / images)'),
                        ),
                        if (_picked.isEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'No attachments selected',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          for (var i = 0; i < _picked.length; i++)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _picked[i].extension?.toLowerCase() == 'pdf'
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.image_outlined,
                              ),
                              title: Text(_picked[i].name),
                              subtitle: Text('${(_picked[i].size / 1024).toStringAsFixed(1)} KB'),
                              trailing: IconButton(
                                tooltip: 'Remove',
                                onPressed: () => _removeFileAt(i),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
    );
  }
}
