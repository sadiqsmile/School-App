import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/student_base.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import '../../shared/homework/homework_details_screen.dart';

class ParentHomeworkListScreen extends ConsumerStatefulWidget {
  const ParentHomeworkListScreen({super.key});

  @override
  ConsumerState<ParentHomeworkListScreen> createState() => _ParentHomeworkListScreenState();
}

class _ParentHomeworkListScreenState extends ConsumerState<ParentHomeworkListScreen> {
  String? _selectedStudentId;
  String? _type; // null=all, homework/notes
  String? _subject;
  bool _onlyWithAttachments = false;

  void _openDetails({required String yearId, required String homeworkId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeworkDetailsScreen(
          yearId: yearId,
          homeworkId: homeworkId,
          showTeacherActions: false,
        ),
      ),
    );
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

  Widget _attachmentChips(List attachments) {
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

    if (attachments.isEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [chip('No attachments', Icons.attachment_outlined)],
      );
    }

    final chips = <Widget>[
      chip('${attachments.length} file(s)', Icons.attach_file),
      if (pdf > 0) chip('PDF: $pdf', Icons.picture_as_pdf_outlined),
      if (img > 0) chip('Images: $img', Icons.image_outlined),
      if (other > 0) chip('Other: $other', Icons.insert_drive_file_outlined),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  @override
  Widget build(BuildContext context) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Homework / Notes')),
      body: yearAsync.when(
        loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (yearId) {
          return FutureBuilder<String?>(
            future: ref.read(authServiceProvider).getParentMobile(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingView(message: 'Loading…'));
              }

              final parentMobile = snap.data;
              if (parentMobile == null || parentMobile.isEmpty) {
                return const Center(child: Text('Please login again.'));
              }

              final childrenStream = ref
                  .read(parentDataServiceProvider)
                  .watchLinkedChildrenBaseStudents(parentMobile: parentMobile);

              return StreamBuilder<List<StudentBase>>(
                stream: childrenStream,
                builder: (context, childrenSnap) {
                  if (childrenSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingView(message: 'Loading children…'));
                  }
                  if (childrenSnap.hasError) {
                    return Center(child: Text('Error: ${childrenSnap.error}'));
                  }

                  final children = childrenSnap.data ?? const <StudentBase>[];
                  if (children.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No child linked to this parent yet.\n\nAsk admin to link students to your parent account (parents/{mobile}.children).',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final selectedId = (children.any((c) => c.id == _selectedStudentId))
                      ? _selectedStudentId!
                      : children.first.id;

                  final selected = children.firstWhere((c) => c.id == selectedId);
                  final classId = selected.classId;
                  final sectionId = selected.sectionId;

                  if (classId == null || sectionId == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(height: 10),
                            const Text(
                              'Your selected child is missing class/section in Firestore.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Student: ${selected.fullName}',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final stream = ref.read(homeworkServiceProvider).watchHomework(
                        yearId: yearId,
                        classId: classId,
                        sectionId: sectionId,
                        subject: _subject,
                        type: _type,
                        onlyActive: true, // parents see only active
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
                                  'Child & Filters',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  key: ValueKey(selectedId),
                                  initialValue: selectedId,
                                  items: [
                                    for (final c in children)
                                      DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.fullName),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() => _selectedStudentId = v),
                                  decoration: const InputDecoration(
                                    labelText: 'Child',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Class',
                                          border: OutlineInputBorder(),
                                        ),
                                        child: Text(classId),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Section',
                                          border: OutlineInputBorder(),
                                        ),
                                        child: Text(sectionId),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
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
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<String?>(
                                        key: ValueKey(_subject),
                                        initialValue: _subject,
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('All subjects')),
                                          for (final s in _subjects())
                                            DropdownMenuItem(value: s, child: Text(s)),
                                        ],
                                        onChanged: (v) => setState(() => _subject = v),
                                        decoration: const InputDecoration(
                                          labelText: 'Subject',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.menu_book_outlined),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _onlyWithAttachments,
                                  onChanged: (v) => setState(() => _onlyWithAttachments = v),
                                  title: const Text('Only show items with attachments'),
                                  subtitle: const Text('Hide items that have no PDF/images'),
                                  secondary: const Icon(Icons.attachment_outlined),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: stream,
                          builder: (context, hwSnap) {
                            if (hwSnap.connectionState == ConnectionState.waiting) {
                              return const Center(child: LoadingView(message: 'Loading…'));
                            }
                            if (hwSnap.hasError) {
                              return Center(child: Text('Error: ${hwSnap.error}'));
                            }

                            final docs = hwSnap.data?.docs ?? const [];
                            final visibleDocs = _onlyWithAttachments
                                ? docs
                                    .where((d) =>
                                        ((d.data()['attachments'] as List?)?.isNotEmpty ?? false))
                                    .toList(growable: false)
                                : docs;

                            if (visibleDocs.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _onlyWithAttachments
                                        ? 'No homework/notes with attachments found for ${selected.fullName}.'
                                        : 'No homework/notes found for ${selected.fullName}.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: visibleDocs.length,
                              itemBuilder: (context, i) {
                                final d = visibleDocs[i];
                                final data = d.data();

                                final title = (data['title'] as String?) ?? 'Untitled';
                                final subject = (data['subject'] as String?) ?? '-';
                                final type = (data['type'] as String?) ?? '-';
                                final ts = data['publishDate'];
                                final date = ts is Timestamp ? ts.toDate() : null;
                                final attachments = (data['attachments'] as List?) ?? const [];

                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      type == 'notes' ? Icons.sticky_note_2_outlined : Icons.assignment_outlined,
                                    ),
                                    title: Text(title),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('$subject • ${date == null ? '—' : _fmt(date)}'),
                                          const SizedBox(height: 8),
                                          _attachmentChips(attachments),
                                        ],
                                      ),
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _openDetails(yearId: yearId, homeworkId: d.id),
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
              );
            },
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
