import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/app_user.dart';
import '../../../models/user_role.dart';
import '../../../models/student_base.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/loading_view.dart';

class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({
    super.key,
    required this.viewerRole,
    this.parentMobile,
  });

  final UserRole viewerRole;
  final String? parentMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: NotificationInboxView(viewerRole: viewerRole, parentMobile: parentMobile),
    );
  }
}

/// Reusable inbox view (no Scaffold/app bar) so it can be embedded in tabs.
class NotificationInboxView extends ConsumerWidget {
  const NotificationInboxView({
    super.key,
    required this.viewerRole,
    this.parentMobile,
  });

  final UserRole viewerRole;
  final String? parentMobile;

  bool _matchesForParent(AppNotification n, List<StudentBase> children, String parentMobile) {
    if (n.scope == NotificationScope.school) return true;

    if (n.scope == NotificationScope.parent) {
      return (n.parentMobile ?? '').trim() == parentMobile.trim();
    }

    if (n.scope == NotificationScope.group) {
      final g = (n.groupId ?? '').trim();
      if (g.isEmpty) return false;
      return children.any((c) => (c.groupId ?? '').trim() == g);
    }

    if (n.scope == NotificationScope.classSection) {
      final c = (n.classId ?? '').trim();
      final s = (n.sectionId ?? '').trim();
      if (c.isEmpty || s.isEmpty) return false;
      return children.any((x) => (x.classId ?? '').trim() == c && (x.sectionId ?? '').trim() == s);
    }

    return false;
  }

  bool _matchesForTeacher(AppNotification n, AppUser teacher, List<String> assignedClassSectionIds) {
    if (n.scope == NotificationScope.school) return true;

    if (n.scope == NotificationScope.group) {
      final g = (n.groupId ?? '').trim();
      return g.isNotEmpty && teacher.assignedGroups.contains(g);
    }

    if (n.scope == NotificationScope.classSection) {
      final c = (n.classId ?? '').trim();
      final s = (n.sectionId ?? '').trim();
      if (c.isEmpty || s.isEmpty) return false;
      final id = '${c}_$s';
      return assignedClassSectionIds.contains(id);
    }

    // Teachers typically won't receive parent-only notifications.
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return yearAsync.when(
      loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (yearId) {
        final notifStream = ref.read(notificationServiceProvider).watchLatest(yearId: yearId);

        return StreamBuilder<List<AppNotification>>(
          stream: notifStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: LoadingView(message: 'Loading notifications…'));
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final all = snap.data ?? const <AppNotification>[];

            if (viewerRole == UserRole.admin) {
              return _InboxList(items: all);
            }

            if (viewerRole == UserRole.teacher) {
              final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
              if (authUser == null) {
                return const Center(child: Text('Please login again.'));
              }

              final appUserAsync = ref.watch(appUserProvider);
              final assignedStream = ref
                  .read(teacherDataServiceProvider)
                  .watchAssignedClassSectionIds(teacherUid: authUser.uid);

              return appUserAsync.when(
                loading: () => const Center(child: LoadingView(message: 'Loading profile…')),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (teacher) {
                  return StreamBuilder<List<String>>(
                    stream: assignedStream,
                    builder: (context, assSnap) {
                      final assigned = assSnap.data ?? const <String>[];
                      final filtered = all
                          .where((n) => _matchesForTeacher(n, teacher, assigned))
                          .toList(growable: false);

                      return _InboxList(items: filtered);
                    },
                  );
                },
              );
            }

            // Parent
            final mobile = (parentMobile ?? '').trim();
            if (mobile.isEmpty) {
              return const Center(child: Text('Please login again.'));
            }

            // We already have a proper parent->children stream in ParentDataService.
            final linkedStream = ref
                .read(parentDataServiceProvider)
                .watchLinkedChildrenBaseStudents(parentMobile: mobile);

            return StreamBuilder<List<StudentBase>>(
              stream: linkedStream,
              builder: (context, childSnap) {
                if (childSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingView(message: 'Loading students…'));
                }
                if (childSnap.hasError) {
                  return Center(child: Text('Error: ${childSnap.error}'));
                }

                final children = childSnap.data ?? const <StudentBase>[];
                final filtered = all
                    .where((n) => _matchesForParent(n, children, mobile))
                    .toList(growable: false);

                return _InboxList(items: filtered);
              },
            );
          },
        );
      },
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.items});

  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No notifications yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final fmt = DateFormat('dd MMM, hh:mm a');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final n = items[i];

        final subtitle = <String>[];
        subtitle.add(AppNotification.scopeLabel(n.scope));
        if (n.scope == NotificationScope.group && (n.groupId ?? '').trim().isNotEmpty) {
          subtitle.add('Group: ${n.groupId}');
        }
        if (n.scope == NotificationScope.classSection && (n.classId ?? '').trim().isNotEmpty) {
          subtitle.add('Class: ${n.classId}-${n.sectionId ?? ''}');
        }
        if (n.createdAt != null) {
          subtitle.add(fmt.format(n.createdAt!));
        }

        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.notifications_active_outlined)),
            title: Text(
              n.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (n.body.trim().isNotEmpty) Text(n.body),
                const SizedBox(height: 6),
                Text(
                  subtitle.join(' • '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
