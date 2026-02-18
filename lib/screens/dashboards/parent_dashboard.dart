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
import '../../utils/parent_auth_email.dart';
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
    final authUserAsync = ref.watch(firebaseAuthUserProvider);

    final authUser = authUserAsync.asData?.value;
    final parentMobile = tryExtractMobileFromParentEmail(authUser?.email);
    final parentUid = authUser?.uid;

    if (authUserAsync.isLoading) {
      return const Scaffold(body: Center(child: LoadingView(message: 'Loading…')));
    }
    if (authUser == null || parentMobile == null || parentUid == null) {
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
                              child: Icon(Icons.family_restroom, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello!',
                                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Parent Portal',
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
              // Children as Horizontal Cards (Swipeable)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Children',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _ChildCard(
                              name: 'Arjun',
                              class_: 'Primary - A',
                              section: 'Section A',
                              grade: 'Primary',
                              color: const Color(0xFF42A5F5),
                            ),
                            const SizedBox(width: 12),
                            _ChildCard(
                              name: 'Ananya',
                              class_: 'Middle - B',
                              section: 'Section B',
                              grade: 'Middle',
                              color: const Color(0xFF66BB6A),
                            ),
                            const SizedBox(width: 12),
                            _ChildCard(
                              name: 'Aditya',
                              class_: 'High - C',
                              section: 'Section C',
                              grade: 'High',
                              color: const Color(0xFFFFA726),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Quick Stats
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                sliver: SliverToBoxAdapter(
                  child: _ParentSummaryRow(
                    yearId: yearId,
                    parentUid: parentMobile,
                    roleLabel: 'parent',
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
                    _ParentActionCard(
                      title: 'Attendance',
                      subtitle: 'View monthly attendance',
                      icon: Icons.event_available_outlined,
                      gradient: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
                      onTap: () => _openScreen(context, const ParentAttendanceScreen()),
                    ),
                    _ParentActionCard(
                      title: 'Homework',
                      subtitle: 'Download notes & PDFs',
                      icon: Icons.menu_book_outlined,
                      gradient: [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
                      onTap: () => _openScreen(context, const ParentHomeworkListScreen()),
                    ),
                    _ParentActionCard(
                      title: 'Chat Teachers',
                      subtitle: 'WhatsApp messaging',
                      icon: Icons.chat_bubble_outline,
                      gradient: [const Color(0xFF00796B), const Color(0xFF004D40)],
                      onTap: () => _openScreen(context, const ParentChatTeachersScreen()),
                    ),
                    _ParentActionCard(
                      title: 'Timetable',
                      subtitle: 'Class schedule',
                      icon: Icons.calendar_month_outlined,
                      gradient: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
                      onTap: () => _openScreen(context, const ParentTimetableScreen()),
                    ),
                    _ParentActionCard(
                      title: 'Exam Results',
                      subtitle: 'Marks and grades',
                      icon: Icons.workspace_premium_outlined,
                      gradient: [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
                      onTap: () => _openScreen(context, const ParentExamsScreen()),
                    ),
                    _ParentActionCard(
                      title: 'Notifications',
                      subtitle: 'School updates',
                      icon: Icons.notifications_active_outlined,
                      gradient: [const Color(0xFF00838F), const Color(0xFF004D40)],
                      onTap: () => _openScreen(
                        context,
                        NotificationInboxScreen(
                          viewerRole: UserRole.parent,
                          parentMobile: parentMobile,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Notifications Preview
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Recent Notifications',
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
                  child: _NotificationsPreview(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openScreen(BuildContext context, Widget screen) {
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

// Parent Action Card with Gradient
class _ParentActionCard extends StatefulWidget {
  const _ParentActionCard({
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
  State<_ParentActionCard> createState() => _ParentActionCardState();
}

class _ParentActionCardState extends State<_ParentActionCard> {
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

// Child Card (Swipeable)
class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.name,
    required this.class_,
    required this.section,
    required this.grade,
    required this.color,
  });

  final String name;
  final String class_;
  final String section;
  final String grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  class_,
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
    );
  }
}

// Notifications Preview
class _NotificationsPreview extends StatelessWidget {
  const _NotificationsPreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    final notifications = [
      (
        icon: Icons.announcement,
        title: 'School Assembly Tomorrow',
        time: '2 hours ago',
        color: scheme.primary,
      ),
      (
        icon: Icons.assignment,
        title: 'Homework Due: Mathematics',
        time: '4 hours ago',
        color: const Color(0xFF2E7D32),
      ),
      (
        icon: Icons.event,
        title: 'Parents Meeting Scheduled',
        time: '1 day ago',
        color: const Color(0xFF6A1B9A),
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < notifications.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < notifications.length - 1 ? 12 : 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: notifications[i].color.withValues(alpha: 0.06),
                border: Border.all(color: notifications[i].color.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: notifications[i].color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      notifications[i].icon,
                      color: notifications[i].color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notifications[i].title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notifications[i].time,
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
