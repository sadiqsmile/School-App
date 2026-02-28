import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/teacher_contact_parents_providers.dart';
import '../../../services/teacher_contact_parents_service.dart';
import '../../../widgets/loading_view.dart';

class TeacherContactParentsScreen extends ConsumerStatefulWidget {
  const TeacherContactParentsScreen({super.key});

  @override
  ConsumerState<TeacherContactParentsScreen> createState() => _TeacherContactParentsScreenState();
}

class _TeacherContactParentsScreenState extends ConsumerState<TeacherContactParentsScreen> {
  String? _groupId;
  String? _classId;
  String? _sectionId;

  bool _activeOnly = true;

  final _searchCtrl = TextEditingController();
  final _messageCtrl = TextEditingController(
    text: 'Please contact me when you are free.',
  );

  @override
  void dispose() {
    _searchCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _buildMessage({
    required String teacherName,
    required StudentParentContactEntry s,
    required String extra,
  }) {
    final admission = (s.admissionNo == null || s.admissionNo!.trim().isEmpty) ? '—' : s.admissionNo!.trim();
    final tail = extra.trim();

    final base =
        'Hi, I am $teacherName from SK School Master. Regarding ${s.studentName} (Class ${s.classId}-${s.sectionId}, Admission No: $admission).';

    if (tail.isEmpty) return base;
    if (tail.startsWith('.')) return '$base $tail';
    return '$base $tail';
  }

  Future<void> _openWhatsApp({
    required String mobile10,
    required String message,
  }) async {
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/91$mobile10?text=$encoded');

    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _snack('Could not open WhatsApp for $mobile10');
    }
  }

  Future<void> _confirmAndOpenForStudent({
    required String teacherName,
    required StudentParentContactEntry s,
  }) async {
    if (!s.hasValidIndianMobile) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid parent mobile'),
          content: Text('Saved value: "${s.parentMobile}"\n\nPlease ask admin to update the parent mobile (10 digits).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final msg = _buildMessage(
      teacherName: teacherName,
      s: s,
      extra: _messageCtrl.text,
    );

    await _openWhatsApp(mobile10: s.cleanedMobile10, message: msg);
  }

  Future<void> _bulkOpenOneByOne({
    required String teacherName,
    required List<StudentParentContactEntry> students,
  }) async {
    final valid = students.where((s) => s.hasValidIndianMobile).toList(growable: false);
    if (valid.isEmpty) {
      _snack('No students with a valid parent mobile number.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send same message to all'),
        content: Text(
          'This will open WhatsApp chats one-by-one (${valid.length} parents).\n\nIt will NOT auto-send messages; you will press send in WhatsApp.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var index = 0;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final s = valid[index];
            final msg = _buildMessage(
              teacherName: teacherName,
              s: s,
              extra: _messageCtrl.text,
            );

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bulk WhatsApp',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text('Opening ${index + 1} of ${valid.length}'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.studentName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text('Class: ${s.classId}-${s.sectionId}  •  Admission: ${s.admissionNo ?? '—'}'),
                          const SizedBox(height: 4),
                          Text('Parent: ${s.cleanedMobile10}'),
                          const Divider(height: 20),
                          Text(
                            msg,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: msg));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Message copied')));
                          }
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Copy message'),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          await _openWhatsApp(mobile10: s.cleanedMobile10, message: msg);
                        },
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Open WhatsApp'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Stop'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: index >= valid.length - 1
                              ? null
                              : () => setSheetState(() => index++),
                          child: Text(index >= valid.length - 1 ? 'Done' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact Parents')),
        body: const Center(child: Text('Please login again.')),
      );
    }

    final appUserAsync = ref.watch(appUserProvider);
    final adminData = ref.read(adminDataServiceProvider);
    final classesStream = adminData.watchClasses();
    final sectionsStream = adminData.watchSections();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Parents'),
      ),
      body: appUserAsync.when(
        loading: () => const Center(child: LoadingView(message: 'Loading profile…')),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (appUser) {
          final teacherName = appUser.displayName;
          final allowedGroups = appUser.assignedGroups;

          if (allowedGroups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No groups assigned to this teacher yet.\n\nAsk admin to set assignedGroups (primary/middle/highschool).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          _groupId ??= allowedGroups.first;
          if (!allowedGroups.contains(_groupId)) {
            _groupId = allowedGroups.first;
          }

          final canQuery = _groupId != null && _classId != null && _sectionId != null;

          final query = canQuery
              ? TeacherContactParentsQuery(
                  groupId: _groupId!,
                  classId: _classId!,
                  sectionId: _sectionId!,
                  activeOnly: _activeOnly,
                )
              : null;

          final studentsAsync = query == null
              ? const AsyncValue<List<StudentParentContactEntry>>.data(<StudentParentContactEntry>[])
              : ref.watch(studentsForTeacherContactProvider(query));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 240,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('group-${_groupId ?? ''}'),
                                initialValue: allowedGroups.contains(_groupId) ? _groupId : null,
                                decoration: const InputDecoration(
                                  labelText: 'Group',
                                  prefixIcon: Icon(Icons.groups_2_outlined),
                                ),
                                items: [
                                  for (final g in allowedGroups)
                                    DropdownMenuItem(value: g, child: Text(g)),
                                ],
                                onChanged: (v) => setState(() => _groupId = v),
                              ),
                            ),
                            StreamBuilder(
                              stream: classesStream,
                              builder: (context, snap) {
                                final docs = snap.data?.docs ?? const [];
                                final ids = docs.map((d) => d.id).toSet();
                                final selected = (_classId != null && ids.contains(_classId)) ? _classId : null;

                                return SizedBox(
                                  width: 240,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey('class-${selected ?? ''}'),
                                    initialValue: selected,
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      prefixIcon: Icon(Icons.class_outlined),
                                    ),
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text((d.data()['name'] as String?) ?? d.id),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _classId = v),
                                  ),
                                );
                              },
                            ),
                            StreamBuilder(
                              stream: sectionsStream,
                              builder: (context, snap) {
                                final docs = snap.data?.docs ?? const [];
                                final ids = docs.map((d) => d.id).toSet();
                                final selected = (_sectionId != null && ids.contains(_sectionId)) ? _sectionId : null;

                                return SizedBox(
                                  width: 240,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey('section-${selected ?? ''}'),
                                    initialValue: selected,
                                    decoration: const InputDecoration(
                                      labelText: 'Section',
                                      prefixIcon: Icon(Icons.segment_outlined),
                                    ),
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text((d.data()['name'] as String?) ?? d.id),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _sectionId = v),
                                  ),
                                );
                              },
                            ),
                            SizedBox(
                              width: 240,
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _activeOnly,
                                onChanged: (v) => setState(() => _activeOnly = v),
                                title: const Text('Active only'),
                                subtitle: const Text('Hide inactive students'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _messageCtrl,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Message (same for all)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.edit_outlined),
                            hintText: 'Type extra message…',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Search student',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: canQuery
                                ? () async {
                                    final list = studentsAsync.asData?.value ?? const <StudentParentContactEntry>[];
                                    await _bulkOpenOneByOne(teacherName: teacherName, students: list);
                                  }
                                : null,
                            icon: const Icon(Icons.forum_outlined),
                            label: const Text('Send same message to all'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: !canQuery
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Select Group, Class, and Section to load students.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : studentsAsync.when(
                        loading: () => const Center(child: LoadingView(message: 'Loading students…')),
                        error: (err, _) => Center(child: Text('Error: $err')),
                        data: (students) {
                          final q = _searchCtrl.text.trim().toLowerCase();
                          final filtered = q.isEmpty
                              ? students
                              : students
                                  .where((s) => s.studentName.toLowerCase().contains(q))
                                  .toList(growable: false);

                          if (students.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No students found for this class/section.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          if (filtered.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No students match “${_searchCtrl.text.trim()}”.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final s = filtered[i];
                              final canChat = s.hasValidIndianMobile;

                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      s.studentName.isEmpty ? '?' : s.studentName.trim().substring(0, 1).toUpperCase(),
                                    ),
                                  ),
                                  title: Text(
                                    s.studentName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Admission: ${s.admissionNo ?? '—'}'),
                                      Text(
                                        s.parentMobile.trim().isEmpty
                                            ? 'Parent mobile: —'
                                            : 'Parent mobile: ${StudentParentContactEntry.cleanMobile(s.parentMobile)}',
                                      ),
                                      if (!canChat && s.parentMobile.trim().isNotEmpty)
                                        Text(
                                          'Invalid number',
                                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                                        ),
                                    ],
                                  ),
                                  trailing: Wrap(
                                    spacing: 6,
                                    children: [
                                      IconButton(
                                        tooltip: 'Copy number',
                                        onPressed: s.parentMobile.trim().isEmpty
                                            ? null
                                            : () async {
                                                final m = StudentParentContactEntry.cleanMobile(s.parentMobile);
                                                await Clipboard.setData(ClipboardData(text: m));
                                                if (mounted) _snack('Copied');
                                              },
                                        icon: const Icon(Icons.copy_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'WhatsApp',
                                        onPressed: canChat
                                            ? () => _confirmAndOpenForStudent(teacherName: teacherName, s: s)
                                            : null,
                                        icon: const Icon(Icons.chat),
                                      ),
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
        },
      ),
    );
  }
}
