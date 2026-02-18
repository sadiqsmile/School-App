import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_role.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';

import '../../widgets/dashboard_ui.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/notification_token_registration_runner.dart';
import '../teacher/attendance/teacher_attendance_setup_screen.dart';
import '../teacher/contact_parents/teacher_contact_parents_screen.dart';
import '../teacher/homework/teacher_homework_list_screen.dart';
import '../teacher/timetable/teacher_timetable_screen.dart';
import '../shared/notifications/notification_center_screen.dart';
import '../teacher/exams/teacher_exams_screen.dart';

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
                  // Premium Gradient Header
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.25),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                                  ),
                                  child: Icon(Icons.school_outlined, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, ${appUser.displayName}',
                                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Teacher Dashboard',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Assigned Groups as Chips
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assigned Classes',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ClassChip(label: 'Primary - A', color: const Color(0xFF42A5F5)),
                              _ClassChip(label: 'Primary - B', color: const Color(0xFF42A5F5)),
                              _ClassChip(label: 'Middle - C', color: const Color(0xFF66BB6A)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Quick Stats
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    sliver: SliverToBoxAdapter(
                      child: _TeacherSummaryRow(
                        yearId: yearId,
                        teacherUid: teacherUid,
                        roleLabel: appUser.role.asString,
                      ),
                    ),
                  ),
                  // Quick Actions Title
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  // Action Cards Grid
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.25,
                      children: [
                        _TeacherActionCard(
                          title: 'Mark Attendance',
                          subtitle: 'Daily class attendance',
                          icon: Icons.fact_check_outlined,
                          gradient: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
                          onTap: () => _open(context, const TeacherAttendanceSetupScreen()),
                        ),
                        _TeacherActionCard(
                          title: 'Add Homework',
                          subtitle: 'Upload notes and files',
                          icon: Icons.upload_file_outlined,
                          gradient: [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
                          onTap: () => _open(context, const TeacherHomeworkListScreen()),
                        ),
                        _TeacherActionCard(
                          title: 'Timetable',
                          subtitle: 'View class schedule',
                          icon: Icons.calendar_month_outlined,
                          gradient: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
                          onTap: () => _open(context, const TeacherTimetableScreen()),
                        ),
                        _TeacherActionCard(
                          title: 'Contact Parents',
                          subtitle: 'WhatsApp messaging',
                          icon: Icons.chat_outlined,
                          gradient: [const Color(0xFF1B5E20), const Color(0xFF0D3817)],
                          onTap: () => _open(context, const TeacherContactParentsScreen()),
                        ),
                        _TeacherActionCard(
                          title: 'Enter Exam Marks',
                          subtitle: 'Mark entry and publish',
                          icon: Icons.edit_note_outlined,
                          gradient: [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
                          onTap: () => _open(context, const TeacherExamsScreen()),
                        ),
                        _TeacherActionCard(
                          title: 'Send Notifications',
                          subtitle: 'Class announcements',
                          icon: Icons.notifications_active_outlined,
                          gradient: [const Color(0xFF00838F), const Color(0xFF004D40)],
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
                  // Today's Schedule Section
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        "Today's Schedule",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    sliver: SliverToBoxAdapter(
                      child: _TodaysSchedulePreview(),
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

// Teacher Action Card with Gradient
class _TeacherActionCard extends StatefulWidget {
  const _TeacherActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  State<_TeacherActionCard> createState() => _TeacherActionCardState();
}

class _TeacherActionCardState extends State<_TeacherActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradient[0].withValues(alpha: _isHovered ? 0.4 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Class Chip
class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Today's Schedule Preview
class _TodaysSchedulePreview extends StatelessWidget {
  const _TodaysSchedulePreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    final schedule = [
      (time: '09:00 - 10:00', class_: 'Primary A', subject: 'Mathematics'),
      (time: '10:15 - 11:15', class_: 'Primary B', subject: 'English'),
      (time: '11:30 - 12:30', class_: 'Middle C', subject: 'Science'),
    ];

    return Column(
      children: [
        for (int i = 0; i < schedule.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < schedule.length - 1 ? 12 : 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.06),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.schedule, color: scheme.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule[i].time,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${schedule[i].class_} • ${schedule[i].subject}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
