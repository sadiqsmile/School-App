import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import 'teacher_add_homework_screen.dart';
import '../../shared/homework/homework_details_screen.dart';

class TeacherHomeworkListScreen extends ConsumerStatefulWidget {
  const TeacherHomeworkListScreen({super.key});

  @override
  ConsumerState<TeacherHomeworkListScreen> createState() => _TeacherHomeworkListScreenState();
}

class _TeacherHomeworkListScreenState extends ConsumerState<TeacherHomeworkListScreen> {
  String? _classId;
  String? _sectionId;
  String? _subject;
  String? _type; // null=all, homework/notes

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<String> _subjects() {
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

  Widget _attachmentChips(List attachments, {required bool isActive}) {
    var pdf = 0;
    var img = 0;
    var other = 0;

    for (final a in attachments) {
      if (a is! Map) {
        other++;
        continue;
      }
      final t = (a['fileType'] ?? '').toString();
      if (t == 'pdf') {
        pdf++;
      } else if (t == 'image') {
        img++;
      } else {
        other++;
      }
    }

    Chip chip(String label, IconData icon) {
      return Chip(
        visualDensity: VisualDensity.compact,
        label: Text(label),
        avatar: Icon(icon, size: 18),
      );
    }

    final chips = <Widget>[
      chip(isActive ? 'Active' : 'Disabled', isActive ? Icons.check_circle_outline : Icons.block_outlined),
      chip('${attachments.length} file(s)', Icons.attach_file),
      if (pdf > 0) chip('PDF: $pdf', Icons.picture_as_pdf_outlined),
      if (img > 0) chip('Images: $img', Icons.image_outlined),
      if (other > 0) chip('Other: $other', Icons.insert_drive_file_outlined),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Future<void> _openAdd() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TeacherAddHomeworkScreen()),
    );
    if (!mounted) return;
    if (ok == true) _snack('Saved');
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Scaffold(body: Center(child: Text('Please login again.')));
    }

    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final classesStream = ref.read(adminDataServiceProvider).watchClasses();
    final sectionsStream = ref.read(adminDataServiceProvider).watchSections();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework / Notes'),
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: _openAdd,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: yearAsync.when(
        loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (yearId) {
          final stream = ref.read(homeworkServiceProvider).watchHomework(
                yearId: yearId,
                classId: _classId,
                sectionId: _sectionId,
                subject: _subject,
                type: _type,
                onlyActive: false, // teacher sees all
              );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
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
                                      border: OutlineInputBorder(),
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
                                  final selected =
                                      (_sectionId != null && ids.contains(_sectionId)) ? _sectionId : null;

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
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.group_outlined),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                key: ValueKey(_subject),
                                initialValue: _subject,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All subjects')),
                                  for (final s in _subjects()) DropdownMenuItem(value: s, child: Text(s)),
                                ],
                                onChanged: (v) => setState(() => _subject = v),
                                decoration: const InputDecoration(
                                  labelText: 'Subject',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.menu_book_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                key: ValueKey(_type),
                                initialValue: _type,
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('All types')),
                                  DropdownMenuItem(value: 'homework', child: Text('Homework')),
                                  DropdownMenuItem(value: 'notes', child: Text('Notes')),
                                ],
                                onChanged: (v) => setState(() => _type = v),
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.filter_list_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: LoadingView(message: 'Loading…'));
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }

                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No homework/notes found.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final data = d.data();
                        final title = (data['title'] as String?) ?? 'Untitled';
                        final subject = (data['subject'] as String?) ?? '-';
                        final type = (data['type'] as String?) ?? '-';
                        final active = (data['isActive'] ?? true) == true;
                        final ts = data['publishDate'];
                        final date = ts is Timestamp ? ts.toDate() : null;
                        final attachments = (data['attachments'] as List?) ?? const [];

                        return Card(
                          child: ListTile(
                            title: Text(title),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$subject • ${date == null ? '—' : _fmt(date)}'),
                                  const SizedBox(height: 8),
                                  _attachmentChips(attachments, isActive: active),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                            leading: Icon(type == 'notes' ? Icons.description_outlined : Icons.edit_note),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HomeworkDetailsScreen(
                                    yearId: yearId,
                                    homeworkId: d.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }
}
