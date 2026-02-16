import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_role.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/loading_view.dart';

class NotificationComposerScreen extends ConsumerStatefulWidget {
  const NotificationComposerScreen({
    super.key,
    required this.viewerRole,
  });

  final UserRole viewerRole;

  @override
  ConsumerState<NotificationComposerScreen> createState() => _NotificationComposerScreenState();
}

class _NotificationComposerScreenState extends ConsumerState<NotificationComposerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _parentMobileCtrl = TextEditingController();

  NotificationScope _scope = NotificationScope.school;

  String? _groupId;
  String? _classId;
  String? _sectionId;

  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _parentMobileCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<String> _defaultGroups() {
    return const ['primary', 'middle', 'highschool'];
  }

  Future<void> _pickParentDialog() async {
    final parentsStream = ref.read(adminDataServiceProvider).watchParents();

    await showDialog<void>(
      context: context,
      builder: (context) {
        String query = '';

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Pick Parent'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (v) => setLocal(() => query = v.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search by name or mobile',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: parentsStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: LoadingView(message: 'Loading parents…'));
                          }
                          if (snap.hasError) {
                            return Center(child: Text('Error: ${snap.error}'));
                          }

                          final docs = snap.data?.docs ?? const [];
                          final items = docs
                              .map((d) {
                                final data = d.data();
                                final mobile = d.id;
                                final name = (data['displayName'] as String?) ?? 'Parent';
                                final active = (data['isActive'] as bool?) ?? true;
                                return (mobile: mobile, name: name, active: active);
                              })
                              .where((p) {
                                if (query.isEmpty) return true;
                                return p.mobile.toLowerCase().contains(query) ||
                                    p.name.toLowerCase().contains(query);
                              })
                              .take(250)
                              .toList(growable: false);

                          if (items.isEmpty) {
                            return const Center(child: Text('No parents match your search.'));
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final p = items[i];
                              return ListTile(
                                title: Text(p.name),
                                subtitle: Text(p.mobile + (p.active ? '' : '  (disabled)')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  _parentMobileCtrl.text = p.mobile;
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _send({required String createdByUid, required String createdByName, required String createdByRole}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      await ref.read(notificationServiceProvider).createNotification(
            title: _titleCtrl.text,
            body: _bodyCtrl.text,
            scope: _scope,
            groupId: _groupId,
            classId: _classId,
            sectionId: _sectionId,
            parentMobile: _parentMobileCtrl.text.trim(),
            createdByUid: createdByUid,
            createdByName: createdByName,
            createdByRole: createdByRole,
          );

      if (!mounted) return;
      _snack('Notification posted to inbox');
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _parentMobileCtrl.clear();

      setState(() {
        _scope = NotificationScope.school;
        _groupId = null;
        _classId = null;
        _sectionId = null;
      });
    } catch (e) {
      if (!mounted) return;
      _snack('Send failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Center(child: Text('Please login again.'));
    }

    final appUserAsync = ref.watch(appUserProvider);

    return appUserAsync.when(
      loading: () => const Center(child: LoadingView(message: 'Loading profile…')),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (appUser) {
        final createdByUid = authUser.uid;
        final createdByName = appUser.displayName;
        final createdByRole = appUser.role.asString;

        // Scope options:
        // - Admin: all scopes
        // - Teacher: all scopes as requested, but we guide them with guardrails.
        final allowedGroups = (widget.viewerRole == UserRole.teacher)
            ? (appUser.assignedGroups.isEmpty ? _defaultGroups() : appUser.assignedGroups)
            : _defaultGroups();

        _groupId ??= allowedGroups.isEmpty ? null : allowedGroups.first;
        if (_groupId != null && !allowedGroups.contains(_groupId)) {
          _groupId = allowedGroups.isEmpty ? null : allowedGroups.first;
        }

        return AbsorbPointer(
          absorbing: _sending,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_sending)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LoadingView(message: 'Sending…'),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Compose',
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
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Title required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bodyCtrl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.message_outlined),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Message required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<NotificationScope>(
                          key: ValueKey('scope-$_scope'),
                          initialValue: _scope,
                          decoration: const InputDecoration(
                            labelText: 'Send to',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.send_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: NotificationScope.school,
                              child: Text('Whole school'),
                            ),
                            DropdownMenuItem(
                              value: NotificationScope.group,
                              child: Text('Group'),
                            ),
                            DropdownMenuItem(
                              value: NotificationScope.classSection,
                              child: Text('Class + Section'),
                            ),
                            DropdownMenuItem(
                              value: NotificationScope.parent,
                              child: Text('Individual Parent'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _scope = v;
                              // Clear irrelevant fields.
                              if (_scope != NotificationScope.group) _groupId = null;
                              if (_scope != NotificationScope.classSection) {
                                _classId = null;
                                _sectionId = null;
                              }
                              if (_scope != NotificationScope.parent) {
                                _parentMobileCtrl.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        if (_scope == NotificationScope.group) ...[
                          DropdownButtonFormField<String>(
                            key: ValueKey('group-${_groupId ?? ''}'),
                            initialValue: _groupId,
                            decoration: const InputDecoration(
                              labelText: 'Group',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.groups_2_outlined),
                            ),
                            items: [
                              for (final g in allowedGroups)
                                DropdownMenuItem(value: g, child: Text(g)),
                            ],
                            onChanged: (v) => setState(() => _groupId = v),
                            validator: (v) => (v == null || v.isEmpty) ? 'Select group' : null,
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (_scope == NotificationScope.classSection) ...[
                          if (widget.viewerRole == UserRole.teacher)
                            StreamBuilder<List<String>>(
                              stream: ref
                                  .read(teacherDataServiceProvider)
                                  .watchAssignedClassSectionIds(teacherUid: createdByUid),
                              builder: (context, snap) {
                                final ids = snap.data ?? const <String>[];
                                if (ids.isEmpty) {
                                  return Card(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        'No assigned class-sections found for your account.\nAsk admin to assign class/section to you.',
                                      ),
                                    ),
                                  );
                                }

                                final currentId = (_classId == null || _sectionId == null)
                                    ? null
                                    : '${_classId}_$_sectionId';

                                return Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      key: ValueKey('assigned-classSection-${currentId ?? ''}'),
                                      initialValue:
                                          (currentId != null && ids.contains(currentId)) ? currentId : null,
                                      decoration: const InputDecoration(
                                        labelText: 'Class + Section (assigned)',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.groups_2_outlined),
                                      ),
                                      items: [
                                        for (final id in ids)
                                          DropdownMenuItem(value: id, child: Text(id.replaceAll('_', ' • '))),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        final parts = v.split('_');
                                        if (parts.length != 2) return;
                                        setState(() {
                                          _classId = parts[0];
                                          _sectionId = parts[1];
                                        });
                                      },
                                      validator: (v) => (v == null || v.isEmpty) ? 'Select class & section' : null,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              },
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    stream: ref.read(adminDataServiceProvider).watchClasses(),
                                    builder: (context, snap) {
                                      final docs = snap.data?.docs ?? const [];
                                      final ids = docs.map((d) => d.id).toSet();
                                      final selected = (_classId != null && ids.contains(_classId)) ? _classId : null;

                                      return DropdownButtonFormField<String>(
                                        key: ValueKey('class-${selected ?? ''}'),
                                        initialValue: selected,
                                        decoration: const InputDecoration(
                                          labelText: 'Class',
                                          border: OutlineInputBorder(),
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
                                        validator: (v) => (v == null || v.isEmpty) ? 'Class required' : null,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    stream: ref.read(adminDataServiceProvider).watchSections(),
                                    builder: (context, snap) {
                                      final docs = snap.data?.docs ?? const [];
                                      final ids = docs.map((d) => d.id).toSet();
                                      final selected = (_sectionId != null && ids.contains(_sectionId)) ? _sectionId : null;

                                      return DropdownButtonFormField<String>(
                                        key: ValueKey('section-${selected ?? ''}'),
                                        initialValue: selected,
                                        decoration: const InputDecoration(
                                          labelText: 'Section',
                                          border: OutlineInputBorder(),
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
                                        validator: (v) => (v == null || v.isEmpty) ? 'Section required' : null,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          if (widget.viewerRole != UserRole.teacher) const SizedBox(height: 12),
                        ],

                        if (_scope == NotificationScope.parent) ...[
                          TextFormField(
                            controller: _parentMobileCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Parent mobile (10 digits)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.phone_outlined),
                              suffixIcon: widget.viewerRole == UserRole.admin
                                  ? IconButton(
                                      tooltip: 'Pick from parents list',
                                      onPressed: _pickParentDialog,
                                      icon: const Icon(Icons.person_search_outlined),
                                    )
                                  : null,
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Mobile required';
                              if (t.length != 10) return 'Must be 10 digits';
                              if (int.tryParse(t) == null) return 'Digits only';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        Card(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Free & no server: This posts to the in-app inbox instantly (Firestore).\n\nFor true push alerts in background on Web/Android, you still need to send via Firebase Console or a server (not used here).',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => _send(
                              createdByUid: createdByUid,
                              createdByName: createdByName,
                              createdByRole: createdByRole,
                            ),
                            icon: const Icon(Icons.send),
                            label: const Text('Post notification'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
