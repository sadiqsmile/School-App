import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../models/student_base.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/teacher_directory_providers.dart';
import '../../../services/teacher_directory_service.dart';
import '../../../widgets/loading_view.dart';

class ParentChatTeachersScreen extends ConsumerStatefulWidget {
  const ParentChatTeachersScreen({super.key});

  @override
  ConsumerState<ParentChatTeachersScreen> createState() => _ParentChatTeachersScreenState();
}

class _ParentChatTeachersScreenState extends ConsumerState<ParentChatTeachersScreen> {
  String? _selectedStudentId;
  String _search = '';
  String? _subject;
  bool _onlyMyClass = true;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _classSectionLabel({required String classId, required String sectionId}) {
    return '${classId.trim()}-${sectionId.trim()}';
  }

  Future<Map<String, dynamic>?> _loadStudentDoc(String studentId) async {
    final snap = await FirebaseFirestore.instance
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('students')
        .doc(studentId)
        .get();
    return snap.data();
  }

  String _digitsOnly(String s) {
    return s.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _openWhatsApp({
    required TeacherDirectoryEntry teacher,
    required Map<String, dynamic> studentData,
    required String subject,
  }) async {
    final phone10 = _digitsOnly(teacher.phone);
    if (phone10.length != 10) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid phone number'),
          content: Text('This teacher does not have a valid 10-digit phone number.\n\nSaved value: "${teacher.phone}"'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final studentName = ((studentData['name'] as String?) ?? (studentData['fullName'] as String?) ?? '').toString().trim();
    final admissionNo = (studentData['admissionNo'] ?? '').toString().trim();
    final classId = ((studentData['class'] as String?) ?? (studentData['classId'] as String?) ?? '').toString().trim();
    final sectionId = ((studentData['section'] as String?) ?? (studentData['sectionId'] as String?) ?? '').toString().trim();

    final studentLabel = studentName.isEmpty ? 'my child' : studentName;

    final detailsParts = <String>[];
    if (classId.isNotEmpty && sectionId.isNotEmpty) {
      detailsParts.add('Class $classId-$sectionId');
    }
    if (admissionNo.isNotEmpty) {
      detailsParts.add('Admission No: $admissionNo');
    }

    final details = detailsParts.isEmpty ? '' : ' (${detailsParts.join(', ')})';

    final text =
        'Hi Teacher ${teacher.displayName}, I am parent of $studentLabel$details. I need help regarding $subject.';

    // wa.me expects country code + number WITHOUT plus.
    final phoneWithCountry = '91$phone10';

    final uri = Uri.parse('https://wa.me/$phoneWithCountry?text=${Uri.encodeComponent(text)}');

    // Best-effort check: on mobile, verify WhatsApp app is installed.
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      final schemeUri = Uri.parse('whatsapp://send?phone=$phoneWithCountry&text=${Uri.encodeComponent(text)}');
      final hasApp = await canLaunchUrl(schemeUri);
      if (!hasApp) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('WhatsApp not installed'),
            content: const Text('Please install WhatsApp to chat with teachers.'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Helpful on Android; iOS will ignore if not supported.
                  final market = Uri.parse('market://details?id=com.whatsapp');
                  final web = Uri.parse('https://play.google.com/store/apps/details?id=com.whatsapp');
                  if (await canLaunchUrl(market)) {
                    await launchUrl(market, mode: LaunchMode.externalApplication);
                  } else {
                    await launchUrl(web, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Get WhatsApp'),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unable to open WhatsApp'),
          content: const Text('Could not launch WhatsApp. Please check your device and try again.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  Future<String?> _pickSubjectIfNeeded(TeacherDirectoryEntry teacher) async {
    if (_subject != null && _subject!.isNotEmpty) return _subject;

    final subs = teacher.subjects;
    if (subs.isEmpty) return 'your subject';
    if (subs.length == 1) return subs.first;

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Select subject'),
                subtitle: Text('This will be used in the auto message.'),
              ),
              for (final s in subs)
                ListTile(
                  title: Text(s),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, s),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyPhone(String phone) async {
    final digits = _digitsOnly(phone);
    await Clipboard.setData(ClipboardData(text: digits.isEmpty ? phone : digits));
    if (mounted) _snack('Number copied');
  }

  Future<void> _callPhone(String phone) async {
    final digits = _digitsOnly(phone);
    if (digits.isEmpty) {
      _snack('Phone number missing');
      return;
    }
    final uri = Uri.parse('tel:$digits');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _snack('Unable to start call');
  }

  @override
  Widget build(BuildContext context) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return FutureBuilder<String?>(
      future: ref.read(authServiceProvider).getParentMobile(),
      builder: (context, mobileSnap) {
        if (mobileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: LoadingView(message: 'Loading…')));
        }

        final parentMobile = mobileSnap.data;
        if (parentMobile == null || parentMobile.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat with Teachers')),
            body: const Center(child: Text('Please login again.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Chat with Teachers')),
          body: yearAsync.when(
            loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (yearId) {
              final childrenStream = ref
                  .read(parentDataServiceProvider)
                  .watchLinkedChildrenBaseStudents(parentMobile: parentMobile);

              return StreamBuilder<List<StudentBase>>(
                stream: childrenStream,
                builder: (context, childSnap) {
                  if (childSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingView(message: 'Loading linked students…'));
                  }
                  if (childSnap.hasError) {
                    return Center(child: Text('Error: ${childSnap.error}'));
                  }

                  final children = childSnap.data ?? const <StudentBase>[];
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

                  _selectedStudentId ??= children.first.id;
                  if (!children.any((c) => c.id == _selectedStudentId)) {
                    _selectedStudentId = children.first.id;
                  }

                  final selected = children.firstWhere((c) => c.id == _selectedStudentId);

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _loadStudentDoc(selected.id),
                    builder: (context, studentSnap) {
                      if (studentSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: LoadingView(message: 'Loading student…'));
                      }
                      if (studentSnap.hasError) {
                        return Center(child: Text('Error: ${studentSnap.error}'));
                      }

                      final studentData = studentSnap.data ?? const <String, dynamic>{};
                      final groupId = ((studentData['group'] as String?) ?? (studentData['groupId'] as String?))?.trim();
                      final classId = ((studentData['class'] as String?) ?? (studentData['classId'] as String?))?.trim();
                      final sectionId = ((studentData['section'] as String?) ?? (studentData['sectionId'] as String?))?.trim();

                      if (groupId == null || groupId.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _StudentPickerCard(
                              yearId: yearId,
                              children: children,
                              selectedStudentId: _selectedStudentId!,
                              onChanged: (id) => setState(() => _selectedStudentId = id),
                            ),
                            const SizedBox(height: 12),
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'This student does not have group set in schools/{schoolId}/students/{studentId}.\n\nChat requires Group to filter teachers.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      final teachersAsync = ref.watch(activeTeachersForGroupProvider(groupId));

                      return teachersAsync.when(
                        loading: () => const Center(child: LoadingView(message: 'Loading teachers…')),
                        error: (err, _) => Center(child: Text('Error: $err')),
                        data: (teachers) {
                          final classSection = (classId != null && classId.isNotEmpty && sectionId != null && sectionId.isNotEmpty)
                              ? _classSectionLabel(classId: classId, sectionId: sectionId)
                              : null;

                          bool classMatch(TeacherDirectoryEntry t) {
                            if (!_onlyMyClass) return true;
                            if (classSection == null) return true;
                            if (t.assignedClasses.isEmpty) return true; // optional field -> don't hide teacher
                            return t.assignedClasses.contains(classSection);
                          }

                          bool subjectMatch(TeacherDirectoryEntry t) {
                            if (_subject == null || _subject!.isEmpty) return true;
                            return t.subjects.map((s) => s.toLowerCase()).contains(_subject!.toLowerCase());
                          }

                          bool searchMatch(TeacherDirectoryEntry t) {
                            final q = _search.trim().toLowerCase();
                            if (q.isEmpty) return true;
                            return t.displayName.toLowerCase().contains(q);
                          }

                          final filtered = teachers.where((t) => classMatch(t) && subjectMatch(t) && searchMatch(t)).toList();
                          filtered.sort((a, b) {
                            // Prefer teachers with a matching subject when a filter is set.
                            final sa = subjectMatch(a) ? 0 : 1;
                            final sb = subjectMatch(b) ? 0 : 1;
                            if (sa != sb) return sa.compareTo(sb);

                            // Prefer teachers with explicit class assignments when class is known.
                            final ca = (classSection != null && a.assignedClasses.isNotEmpty) ? 0 : 1;
                            final cb = (classSection != null && b.assignedClasses.isNotEmpty) ? 0 : 1;
                            if (ca != cb) return ca.compareTo(cb);

                            return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
                          });

                          final allSubjects = <String>{};
                          for (final t in teachers.where(classMatch)) {
                            for (final s in t.subjects) {
                              if (s.trim().isNotEmpty) allSubjects.add(s.trim());
                            }
                          }
                          final subjectsList = allSubjects.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                          final effectiveSubject = (_subject != null && _subject!.isNotEmpty && subjectsList.contains(_subject)) ? _subject : null;

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
                                        _StudentPickerCard(
                                          yearId: yearId,
                                          children: children,
                                          selectedStudentId: _selectedStudentId!,
                                          onChanged: (id) => setState(() {
                                            _selectedStudentId = id;
                                            _subject = null;
                                            _search = '';
                                          }),
                                        ),
                                        const SizedBox(height: 12),
                                        if (classSection != null)
                                          SwitchListTile.adaptive(
                                            contentPadding: EdgeInsets.zero,
                                            value: _onlyMyClass,
                                            title: const Text('Only show my child’s class teachers'),
                                            subtitle: Text('Class: $classSection'),
                                            onChanged: (v) => setState(() => _onlyMyClass = v),
                                          ),
                                        TextField(
                                          decoration: const InputDecoration(
                                            labelText: 'Search teacher by name',
                                            prefixIcon: Icon(Icons.search),
                                          ),
                                          onChanged: (v) => setState(() => _search = v),
                                        ),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<String?>(
                                          key: ValueKey('subject-${_subject ?? ''}'),
                                          initialValue: effectiveSubject,
                                          decoration: const InputDecoration(
                                            labelText: 'Filter by subject',
                                            prefixIcon: Icon(Icons.filter_list_outlined),
                                          ),
                                          items: [
                                            const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text('All subjects'),
                                            ),
                                            for (final s in subjectsList)
                                              DropdownMenuItem<String?>(
                                                value: s,
                                                child: Text(s),
                                              ),
                                          ],
                                          onChanged: (v) => setState(() => _subject = v),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Chip(
                                              avatar: const Icon(Icons.groups_2_outlined, size: 18),
                                              label: Text('Group: $groupId'),
                                            ),
                                            if (classSection != null)
                                              Chip(
                                                avatar: const Icon(Icons.class_outlined, size: 18),
                                                label: Text('Class: $classSection'),
                                              ),
                                            if (_search.trim().isNotEmpty)
                                              InputChip(
                                                label: Text('Search: "${_search.trim()}"'),
                                                onDeleted: () => setState(() => _search = ''),
                                              ),
                                            if (effectiveSubject != null)
                                              InputChip(
                                                label: Text('Subject: $effectiveSubject'),
                                                onDeleted: () => setState(() => _subject = null),
                                              ),
                                            InputChip(
                                              label: Text('Showing ${filtered.length} of ${teachers.length}'),
                                              onPressed: null,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.search_off_outlined, size: 44),
                                              const SizedBox(height: 10),
                                              const Text('No teachers found'),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Try clearing filters, or disable “Only my child’s class teachers”.',
                                                style: Theme.of(context).textTheme.bodySmall,
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                alignment: WrapAlignment.center,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: () => setState(() {
                                                      _search = '';
                                                      _subject = null;
                                                    }),
                                                    icon: const Icon(Icons.filter_alt_off_outlined),
                                                    label: const Text('Clear filters'),
                                                  ),
                                                  if (classSection != null)
                                                    OutlinedButton.icon(
                                                      onPressed: () => setState(() => _onlyMyClass = false),
                                                      icon: const Icon(Icons.groups_2_outlined),
                                                      label: const Text('Show all group teachers'),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                                        itemBuilder: (context, i) {
                                          final t = filtered[i];
                                          final initials = t.displayName.isNotEmpty ? t.displayName.trim().substring(0, 1).toUpperCase() : 'T';
                                          final subtitleLines = <String>[];
                                          if (t.subjects.isNotEmpty) subtitleLines.add(t.subjects.join(' • '));
                                          if (t.assignedClasses.isNotEmpty) subtitleLines.add('Classes: ${t.assignedClasses.join(', ')}');
                                          subtitleLines.add('Groups: ${t.assignedGroups.join(', ')}');

                                          return Card(
                                            child: Column(
                                              children: [
                                                ListTile(
                                                  leading: CircleAvatar(child: Text(initials)),
                                                  title: Text(
                                                    t.displayName,
                                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                                  ),
                                                  subtitle: Text('Phone: ${t.phone}\n${subtitleLines.join('\n')}'),
                                                  isThreeLine: true,
                                                  trailing: Wrap(
                                                    spacing: 6,
                                                    children: [
                                                      PopupMenuButton<String>(
                                                        tooltip: 'More',
                                                        onSelected: (value) async {
                                                          switch (value) {
                                                            case 'copy':
                                                              await _copyPhone(t.phone);
                                                              break;
                                                            case 'call':
                                                              await _callPhone(t.phone);
                                                              break;
                                                          }
                                                        },
                                                        itemBuilder: (context) => const [
                                                          PopupMenuItem(value: 'copy', child: Text('Copy number')),
                                                          PopupMenuItem(value: 'call', child: Text('Call')),
                                                        ],
                                                      ),
                                                      FilledButton.icon(
                                                        onPressed: () async {
                                                          final pickedSubject = await _pickSubjectIfNeeded(t);
                                                          if (pickedSubject == null || pickedSubject.isEmpty) return;
                                                          if (!mounted) return;
                                                          await _openWhatsApp(
                                                            teacher: t,
                                                            studentData: studentData,
                                                            subject: pickedSubject,
                                                          );
                                                        },
                                                        icon: const Icon(Icons.chat_bubble_outline),
                                                        label: const Text('Chat'),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        if (t.subjects.isEmpty)
                                                          const Chip(label: Text('No subjects'))
                                                        else
                                                          for (final s in t.subjects)
                                                            InputChip(
                                                              label: Text(s),
                                                              onPressed: () => setState(() => _subject = s),
                                                            ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
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
              );
            },
          ),
        );
      },
    );
  }
}

class _StudentPickerCard extends StatelessWidget {
  const _StudentPickerCard({
    required this.yearId,
    required this.children,
    required this.selectedStudentId,
    required this.onChanged,
  });

  final String yearId;
  final List<StudentBase> children;
  final String selectedStudentId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Select child',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text('Year: $yearId', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('child-$selectedStudentId'),
          initialValue: selectedStudentId,
          decoration: const InputDecoration(
            labelText: 'Child',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: [
            for (final c in children)
              DropdownMenuItem(
                value: c.id,
                child: Text(c.fullName),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ],
    );
  }
}
