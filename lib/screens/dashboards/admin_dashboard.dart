import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../models/user_role.dart';

import '../../widgets/dashboard_ui.dart';
import '../admin/attendance/admin_attendance_screen.dart';
import '../admin/classes/admin_classes_sections_screen.dart';
import '../admin/parents/admin_parents_screen.dart';
import '../admin/setup/admin_setup_wizard_screen.dart';
import '../admin/students/admin_students_screen.dart';
import '../admin/teachers/admin_teachers_screen.dart';
import '../admin/timetable/admin_timetable_screen.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/notification_token_registration_runner.dart';
import '../shared/notifications/notification_center_screen.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;

  static const _items = <_AdminNavItem>[
    _AdminNavItem('Setup Wizard', Icons.auto_fix_high, _AdminPage.setupWizard),
    _AdminNavItem('Dashboard', Icons.dashboard, _AdminPage.dashboard),
    _AdminNavItem('Students', Icons.badge, _AdminPage.students),
    _AdminNavItem('Attendance', Icons.fact_check_outlined, _AdminPage.attendance),
    _AdminNavItem('Parents', Icons.family_restroom, _AdminPage.parents),
    _AdminNavItem('Teachers', Icons.person, _AdminPage.teachers),
    _AdminNavItem('Classes/Sections', Icons.class_, _AdminPage.classes),
    _AdminNavItem('Timetable', Icons.calendar_month, _AdminPage.timetable),
    _AdminNavItem('Exams', Icons.school, _AdminPage.exams),
    _AdminNavItem('Notifications', Icons.notifications, _AdminPage.notifications),
  ];

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(appUserProvider);
    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final authUserAsync = ref.watch(firebaseAuthUserProvider);

    return appUserAsync.when(
      loading: () => const Scaffold(body: Center(child: LoadingView(message: 'Loading…'))),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (appUser) {
        final adminUid = authUserAsync.asData?.value?.uid;
        final isWide = MediaQuery.sizeOf(context).width >= 900;
        final selected = _items[_selectedIndex];
        final scheme = Theme.of(context).colorScheme;

        final yearText = yearAsync.when(
          data: (yearId) => 'Academic Year: $yearId',
          loading: () => 'Academic Year: …',
          error: (_, _) => 'Academic Year: (not set)',
        );

        final yearId = yearAsync.asData?.value;

        final header = DashboardHeaderCard(
          title: 'Hello, ${appUser.displayName}',
          subtitle: yearText,
          trailing: Icon(Icons.admin_panel_settings_outlined, color: scheme.primary),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('Admin • ${selected.label}'),
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
          drawer: isWide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DrawerHeader(
                          child: header,
                        ),
                        for (var i = 0; i < _items.length; i++)
                          ListTile(
                            selected: i == _selectedIndex,
                            leading: Icon(_items[i].icon),
                            title: Text(_items[i].label),
                            onTap: () {
                              setState(() => _selectedIndex = i);
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
          body: DashboardBackground(
            child: Row(
              children: [
                if (isWide)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    backgroundColor: Colors.transparent,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final item in _items)
                        NavigationRailDestination(
                          icon: Icon(item.icon),
                          label: Text(item.label),
                        ),
                    ],
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: header,
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      _AdminContent(
                    onNavigate: (page) {
                      final idx = _items.indexWhere((x) => x.page == page);
                      if (idx >= 0) setState(() => _selectedIndex = idx);
                    },
                    page: selected.page,
                    activeYearId: yearId,
                      ),
                      // Invisible token registration runner.
                      if (adminUid != null)
                        NotificationTokenRegistrationRunner.user(
                          uid: adminUid,
                          // TODO: For Web Push you must provide a VAPID key.
                          // vapidKey: 'YOUR_WEB_PUSH_VAPID_KEY',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminContent extends ConsumerWidget {
  const _AdminContent({
    required this.page,
    required this.onNavigate,
    required this.activeYearId,
  });

  final _AdminPage page;
  final ValueChanged<_AdminPage> onNavigate;
  final String? activeYearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page == _AdminPage.setupWizard) {
      return const AdminSetupWizardScreen();
    }
    if (page == _AdminPage.students) {
      return const AdminStudentsScreen();
    }
    if (page == _AdminPage.attendance) {
      return const AdminAttendanceScreen();
    }
    if (page == _AdminPage.parents) {
      return const AdminParentsScreen();
    }
    if (page == _AdminPage.teachers) {
      return const AdminTeachersScreen();
    }
    if (page == _AdminPage.classes) {
      return const AdminClassesSectionsScreen();
    }
    if (page == _AdminPage.timetable) {
      return const AdminTimetableScreen();
    }

    if (page == _AdminPage.notifications) {
      return const NotificationCenterScreen(viewerRole: UserRole.admin);
    }

    if (page == _AdminPage.dashboard) {
      final scheme = Theme.of(context).colorScheme;
      final width = MediaQuery.sizeOf(context).width;
      final crossAxisCount = width >= 1100
          ? 3
          : width >= 720
              ? 2
              : 1;

      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _AdminSummaryRow(activeYearId: activeYearId),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Quick actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
                  title: 'Setup Wizard',
                  subtitle: 'Guided setup for your school',
                  icon: Icons.auto_fix_high,
                  tint: scheme.primary,
                  animationOrder: 0,
                  onTap: () => onNavigate(_AdminPage.setupWizard),
                ),
                DashboardActionCard(
                  title: 'Students',
                  subtitle: 'Create and assign to class/section',
                  icon: Icons.badge_outlined,
                  tint: scheme.secondary,
                  animationOrder: 1,
                  onTap: () => onNavigate(_AdminPage.students),
                ),
                DashboardActionCard(
                  title: 'Parents',
                  subtitle: 'Create parent accounts and link students',
                  icon: Icons.family_restroom,
                  tint: const Color(0xFF1565C0),
                  animationOrder: 2,
                  onTap: () => onNavigate(_AdminPage.parents),
                ),
                DashboardActionCard(
                  title: 'Teachers',
                  subtitle: 'Create teacher accounts and assign classes',
                  icon: Icons.person_outline,
                  tint: const Color(0xFF2E7D32),
                  animationOrder: 3,
                  onTap: () => onNavigate(_AdminPage.teachers),
                ),
                DashboardActionCard(
                  title: 'Classes/Sections',
                  subtitle: 'Manage class levels and sections',
                  icon: Icons.class_outlined,
                  tint: const Color(0xFF00838F),
                  animationOrder: 4,
                  onTap: () => onNavigate(_AdminPage.classes),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final title = switch (page) {
      _AdminPage.setupWizard => 'Admin Setup Wizard',
      _AdminPage.dashboard => 'Admin Dashboard',
      _AdminPage.students => 'Manage Students',
      _AdminPage.attendance => 'Attendance Report',
      _AdminPage.parents => 'Manage Parents',
      _AdminPage.teachers => 'Manage Teachers',
      _AdminPage.classes => 'Manage Classes/Sections',
      _AdminPage.timetable => 'Manage Timetable',
      _AdminPage.exams => 'Manage Exams & Results',
      _AdminPage.notifications => 'Send Notifications',
    };

    final desc = switch (page) {
      _AdminPage.setupWizard =>
        'Guided setup: academic year → classes → accounts → assignments → verify attendance.',
      _AdminPage.dashboard =>
        'Overview: total students, attendance, and recent notices.',
      _AdminPage.students =>
        'Add/Edit/Delete students and assign to class/section for the academic year.',
      _AdminPage.attendance =>
        'View class/section attendance for a date and copy an export-ready table.',
      _AdminPage.parents =>
        'Create parent accounts (mobile login) and link to students.',
      _AdminPage.teachers => 'Create teacher accounts and assign classes/sections.',
      _AdminPage.classes => 'Create classes and sections (A/B/C).',
      _AdminPage.timetable => 'Upload timetable for each class/section.',
      _AdminPage.exams => 'Create exams, enter marks, and publish results.',
      _AdminPage.notifications =>
        'Send notifications school-wide or class-wise (FCM + Firestore).',
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(desc),
                  const SizedBox(height: 12),
                  Text(
                    'UI for this module will be built next. The database design and security rules are already prepared for it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSummaryRow extends ConsumerWidget {
  const _AdminSummaryRow({required this.activeYearId});

  final String? activeYearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final adminData = ref.read(adminDataServiceProvider);

    final yearValue = activeYearId ?? '—';

    String countText(AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
      if (snap.connectionState == ConnectionState.waiting) return '…';
      if (snap.hasError) return '—';
      return (snap.data?.docs.length ?? 0).toString();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: adminData.watchStudents(),
      builder: (context, studentsSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: adminData.watchTeachers(),
          builder: (context, teachersSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: adminData.watchParents(),
              builder: (context, parentsSnap) {
                return DashboardSummaryStrip(
                  items: [
                    DashboardSummaryItemData(
                      label: 'Students',
                      value: countText(studentsSnap),
                      icon: Icons.badge_outlined,
                      tint: scheme.primary,
                    ),
                    DashboardSummaryItemData(
                      label: 'Teachers',
                      value: countText(teachersSnap),
                      icon: Icons.person_outline,
                      tint: scheme.secondary,
                    ),
                    DashboardSummaryItemData(
                      label: 'Parents',
                      value: countText(parentsSnap),
                      icon: Icons.family_restroom,
                      tint: scheme.tertiary,
                    ),
                    DashboardSummaryItemData(
                      label: 'Academic year',
                      value: yearValue,
                      icon: Icons.calendar_today_outlined,
                      tint: const Color(0xFF1565C0),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _AdminPage {
  setupWizard,
  dashboard,
  students,
  attendance,
  parents,
  teachers,
  classes,
  timetable,
  exams,
  notifications,
}

class _AdminNavItem {
  const _AdminNavItem(this.label, this.icon, this.page);

  final String label;
  final IconData icon;
  final _AdminPage page;
}
