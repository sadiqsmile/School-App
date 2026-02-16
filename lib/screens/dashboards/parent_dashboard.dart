import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/parent_student.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../models/user_role.dart';

import '../../widgets/dashboard_ui.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/notification_token_registration_runner.dart';
import '../parent/students/student_list_screen.dart';
import '../parent/attendance/parent_attendance_screen.dart';
import '../parent/homework/parent_homework_list_screen.dart';
import '../parent/chat/parent_chat_teachers_screen.dart';
import '../parent/timetable/parent_timetable_screen.dart';
import '../shared/notifications/notification_inbox_screen.dart';
import '../parent/exams/parent_exams_screen.dart';
import '../parent/settings/parent_settings_screen.dart';

class ParentDashboard extends ConsumerWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return FutureBuilder<String?>(
      future: ref.read(authServiceProvider).getParentMobile(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: LoadingView(message: 'Loading…')));
        }
        final parentMobile = snap.data;
        if (parentMobile == null || parentMobile.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Parent Dashboard')),
            body: const Center(child: Text('Please login again.')),
          );
        }

        final scheme = Theme.of(context).colorScheme;
        final width = MediaQuery.sizeOf(context).width;
        final crossAxisCount = width >= 900
            ? 3
            : width >= 560
                ? 2
                : 1;

        final yearText = yearAsync.when(
          data: (yearId) => 'Academic Year: $yearId',
          loading: () => 'Academic Year: …',
          error: (_, _) => 'Academic Year: (not set)',
        );

        final yearId = yearAsync.asData?.value;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Parent Dashboard'),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: DashboardBackground(
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: NotificationTokenRegistrationRunner.parent(
                      parentMobile: parentMobile,
                      // TODO: For Web Push you must provide a VAPID key.
                      // vapidKey: 'YOUR_WEB_PUSH_VAPID_KEY',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: DashboardHeaderCard(
                        title: 'Hello',
                        subtitle: '$yearText\nMobile: $parentMobile\nRole: parent',
                        trailing: Icon(Icons.verified_user_outlined, color: scheme.primary),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _ParentSummaryRow(
                        yearId: yearId,
                        parentUid: parentMobile,
                        roleLabel: 'parent',
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.25,
                      children: [
                        DashboardActionCard(
                          title: 'Student Profile',
                          subtitle: 'Name, class, section, photo, admission no',
                          icon: Icons.badge_outlined,
                          tint: scheme.primary,
                          animationOrder: 0,
                          onTap: () => _open(context, const StudentListScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Attendance',
                          subtitle: 'Monthly calendar + percentage',
                          icon: Icons.event_available_outlined,
                          tint: scheme.secondary,
                          animationOrder: 1,
                          onTap: () => _open(context, const ParentAttendanceScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Homework / Notes',
                          subtitle: 'Download PDFs/images',
                          icon: Icons.menu_book_outlined,
                          tint: const Color(0xFF2E7D32),
                          animationOrder: 2,
                          onTap: () => _open(context, const ParentHomeworkListScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Chat with Teachers',
                          subtitle: 'WhatsApp subject-wise',
                          icon: Icons.chat_bubble_outline,
                          tint: const Color(0xFF00796B),
                          animationOrder: 3,
                          onTap: () => _open(context, const ParentChatTeachersScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Timetable',
                          subtitle: 'Class timetable',
                          icon: Icons.calendar_month_outlined,
                          tint: const Color(0xFF1565C0),
                          animationOrder: 4,
                          onTap: () => _open(context, const ParentTimetableScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Exam Results',
                          subtitle: 'Marks and grade',
                          icon: Icons.workspace_premium_outlined,
                          tint: const Color(0xFF6A1B9A),
                          animationOrder: 5,
                          onTap: () => _open(context, const ParentExamsScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Notifications',
                          subtitle: 'School and class updates',
                          icon: Icons.notifications_active_outlined,
                          tint: const Color(0xFF00838F),
                          animationOrder: 6,
                          onTap: () => _open(
                            context,
                            NotificationInboxScreen(
                              viewerRole: UserRole.parent,
                              parentMobile: parentMobile,
                            ),
                          ),
                        ),
                        DashboardActionCard(
                          title: 'Settings',
                          subtitle: 'Change password, sign out',
                          icon: Icons.settings_outlined,
                          tint: const Color(0xFF37474F),
                          animationOrder: 7,
                          onTap: () => _open(context, const ParentSettingsScreen()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ParentSummaryRow extends ConsumerWidget {
  const _ParentSummaryRow({
    required this.yearId,
    required this.parentUid,
    required this.roleLabel,
  });

  final String? yearId;
  final String? parentUid;
  final String roleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    if (yearId == null || parentUid == null) {
      return DashboardSummaryStrip(
        items: [
          DashboardSummaryItemData(
            label: 'Linked students',
            value: '…',
            icon: Icons.group_outlined,
            tint: scheme.primary,
          ),
          DashboardSummaryItemData(
            label: 'Academic year',
            value: yearId ?? '…',
            icon: Icons.calendar_today_outlined,
            tint: scheme.secondary,
          ),
          DashboardSummaryItemData(
            label: 'Role',
            value: roleLabel,
            icon: Icons.verified_user_outlined,
            tint: scheme.tertiary,
          ),
        ],
      );
    }

    final stream = ref
        .read(parentDataServiceProvider)
        .watchMyStudents(yearId: yearId!, parentUid: parentUid!);

    return StreamBuilder<List<ParentStudent>>(
      stream: stream,
      builder: (context, snapshot) {
        final studentsValue = switch (snapshot.connectionState) {
          ConnectionState.waiting => '…',
          _ => snapshot.hasError
              ? '—'
              : (snapshot.data?.length ?? 0).toString(),
        };

        return DashboardSummaryStrip(
          items: [
            DashboardSummaryItemData(
              label: 'Linked students',
              value: studentsValue,
              icon: Icons.group_outlined,
              tint: scheme.primary,
            ),
            DashboardSummaryItemData(
              label: 'Academic year',
              value: yearId!,
              icon: Icons.calendar_today_outlined,
              tint: scheme.secondary,
            ),
            DashboardSummaryItemData(
              label: 'Role',
              value: roleLabel,
              icon: Icons.verified_user_outlined,
              tint: scheme.tertiary,
            ),
          ],
        );
      },
    );
  }
}
