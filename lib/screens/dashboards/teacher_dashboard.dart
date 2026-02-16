import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_role.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';

import '../../widgets/dashboard_ui.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/feature_placeholder_screen.dart';
import '../../widgets/notification_token_registration_runner.dart';
import '../teacher/attendance/teacher_attendance_setup_screen.dart';
import '../teacher/contact_parents/teacher_contact_parents_screen.dart';
import '../teacher/homework/teacher_homework_list_screen.dart';
import '../teacher/timetable/teacher_timetable_screen.dart';
import '../shared/notifications/notification_center_screen.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final authUserAsync = ref.watch(firebaseAuthUserProvider);

    return appUserAsync.when(
      loading: () => const Scaffold(body: Center(child: LoadingView(message: 'Loading…'))),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Teacher Dashboard')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (appUser) {
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
        final teacherUid = authUserAsync.asData?.value?.uid;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Teacher Dashboard'),
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
                    child: teacherUid == null
                        ? const SizedBox.shrink()
                        : NotificationTokenRegistrationRunner.user(
                            uid: teacherUid,
                            // TODO: For Web Push you must provide a VAPID key.
                            // vapidKey: 'YOUR_WEB_PUSH_VAPID_KEY',
                          ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: DashboardHeaderCard(
                        title: 'Hello, ${appUser.displayName}',
                        subtitle: '$yearText\nRole: ${appUser.role.asString}',
                        trailing: Icon(Icons.school_outlined, color: scheme.primary),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _TeacherSummaryRow(
                        yearId: yearId,
                        teacherUid: teacherUid,
                        roleLabel: appUser.role.asString,
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
                          title: 'Teacher Profile',
                          subtitle: 'Your details and assigned classes',
                          icon: Icons.person_outline,
                          tint: scheme.primary,
                          animationOrder: 0,
                          onTap: () => _open(
                            context,
                            const FeaturePlaceholderScreen(
                              title: 'Teacher Profile',
                              description: 'This screen will show teacher profile from Firestore.',
                            ),
                          ),
                        ),
                        DashboardActionCard(
                          title: 'Select Class/Section',
                          subtitle: 'Choose your class for today',
                          icon: Icons.view_list_outlined,
                          tint: scheme.secondary,
                          animationOrder: 1,
                          onTap: () => _open(
                            context,
                            const FeaturePlaceholderScreen(
                              title: 'Select Class/Section',
                              description:
                                  'This screen will list assigned class/section for the teacher.',
                            ),
                          ),
                        ),
                        DashboardActionCard(
                          title: 'Mark Attendance',
                          subtitle: 'Daily attendance for selected class',
                          icon: Icons.fact_check_outlined,
                          tint: const Color(0xFF1565C0),
                          animationOrder: 2,
                          onTap: () => _open(context, const TeacherAttendanceSetupScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Upload Homework/Notes',
                          subtitle: 'PDF + images to Firebase Storage',
                          icon: Icons.upload_file_outlined,
                          tint: const Color(0xFF2E7D32),
                          animationOrder: 3,
                          onTap: () => _open(context, const TeacherHomeworkListScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Timetable',
                          subtitle: 'View class timetable',
                          icon: Icons.calendar_month_outlined,
                          tint: const Color(0xFF1565C0),
                          animationOrder: 4,
                          onTap: () => _open(context, const TeacherTimetableScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Contact Parents',
                          subtitle: 'WhatsApp chat (class-wise)',
                          icon: Icons.chat_outlined,
                          tint: const Color(0xFF1B5E20),
                          animationOrder: 5,
                          onTap: () => _open(context, const TeacherContactParentsScreen()),
                        ),
                        DashboardActionCard(
                          title: 'Enter Exam Marks',
                          subtitle: 'Enter marks and publish later',
                          icon: Icons.edit_note_outlined,
                          tint: const Color(0xFF6A1B9A),
                          animationOrder: 6,
                          onTap: () => _open(
                            context,
                            const FeaturePlaceholderScreen(
                              title: 'Enter Exam Marks',
                              description: 'This screen will write marks to Firestore.',
                            ),
                          ),
                        ),
                        DashboardActionCard(
                          title: 'Send Notifications',
                          subtitle: 'Class-wise announcements',
                          icon: Icons.notifications_active_outlined,
                          tint: const Color(0xFF00838F),
                          animationOrder: 7,
                          onTap: () => _open(
                            context,
                            const NotificationCenterScreen(
                              viewerRole: UserRole.teacher,
                              initialTab: 1,
                            ),
                          ),
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

class _TeacherSummaryRow extends ConsumerWidget {
  const _TeacherSummaryRow({
    required this.yearId,
    required this.teacherUid,
    required this.roleLabel,
  });

  final String? yearId;
  final String? teacherUid;
  final String roleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    if (yearId == null || teacherUid == null) {
      return DashboardSummaryStrip(
        items: [
          DashboardSummaryItemData(
            label: 'Assigned class-sections',
            value: '…',
            icon: Icons.groups_2_outlined,
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
            icon: Icons.school_outlined,
            tint: scheme.tertiary,
          ),
        ],
      );
    }

    final stream = ref
        .read(teacherDataServiceProvider)
        .watchAssignedClassSectionIds(teacherUid: teacherUid!);

    return StreamBuilder<List<String>>(
      stream: stream,
      builder: (context, snapshot) {
        final assignedValue = switch (snapshot.connectionState) {
          ConnectionState.waiting => '…',
          _ => snapshot.hasError
              ? '—'
              : (snapshot.data?.length ?? 0).toString(),
        };

        return DashboardSummaryStrip(
          items: [
            DashboardSummaryItemData(
              label: 'Assigned class-sections',
              value: assignedValue,
              icon: Icons.groups_2_outlined,
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
              icon: Icons.school_outlined,
              tint: scheme.tertiary,
            ),
          ],
        );
      },
    );
  }
}
