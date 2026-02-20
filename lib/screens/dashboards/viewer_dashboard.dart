import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../models/user_role.dart';
import '../../widgets/dashboard_ui.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/notification_token_registration_runner.dart';

import '../admin/academic_year/admin_academic_year_settings_screen.dart';
import '../admin/students/admin_students_screen.dart';
import '../admin/attendance/admin_attendance_screen.dart';
import '../admin/parents/admin_parents_screen.dart';
import '../admin/teachers/admin_teachers_screen.dart';
import '../admin/classes/admin_classes_sections_screen.dart';
import '../admin/timetable/admin_timetable_screen.dart';
import '../admin/exams/admin_exams_screen.dart';
import '../admin/homework/admin_homework_maintenance_screen.dart';
import '../shared/notifications/notification_center_screen.dart';

class ViewerDashboard extends ConsumerStatefulWidget {
  const ViewerDashboard({super.key});

  @override
  ConsumerState<ViewerDashboard> createState() => _ViewerDashboardState();
}

class _ViewerDashboardState extends ConsumerState<ViewerDashboard> {
  int _selectedIndex = 0;

  static const _items = <_ViewerNavItem>[
    _ViewerNavItem('Dashboard', Icons.dashboard, _ViewerPage.dashboard),
    _ViewerNavItem('Academic Year', Icons.calendar_today, _ViewerPage.academicYear),
    _ViewerNavItem('Students', Icons.badge, _ViewerPage.students),
    _ViewerNavItem('Attendance', Icons.fact_check_outlined, _ViewerPage.attendance),
    _ViewerNavItem('Parents', Icons.family_restroom, _ViewerPage.parents),
    _ViewerNavItem('Teachers', Icons.person, _ViewerPage.teachers),
    _ViewerNavItem('Classes/Sections', Icons.class_, _ViewerPage.classes),
    _ViewerNavItem('Timetable', Icons.calendar_month, _ViewerPage.timetable),
    _ViewerNavItem('Exams', Icons.school, _ViewerPage.exams),
    _ViewerNavItem('Homework Tools', Icons.archive_outlined, _ViewerPage.homeworkTools),
    _ViewerNavItem('Notifications', Icons.notifications, _ViewerPage.notifications),
  ];

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(appUserProvider);
    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final authUserAsync = ref.watch(firebaseAuthUserProvider);

    return appUserAsync.when(
      loading: () => const Scaffold(body: Center(child: LoadingView(message: 'Loading…'))),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Viewer Dashboard')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (appUser) {
        final viewerUid = authUserAsync.asData?.value?.uid;
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
          trailing: Icon(Icons.visibility, color: scheme.primary),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('Viewer • ${selected.label}'),
            actions: [
              // View-only badge
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade700, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'VIEW ONLY',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
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
                      _ViewerContent(page: selected.page, activeYearId: yearId),
                      // Invisible token registration runner
                      if (viewerUid != null)
                        NotificationTokenRegistrationRunner.user(uid: viewerUid),
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

class _ViewerContent extends ConsumerWidget {
  const _ViewerContent({
    required this.page,
    required this.activeYearId,
  });

  final _ViewerPage page;
  final String? activeYearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // View-only banner
    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.orange.shade700, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            'You are in VIEW ONLY mode. Please do not modify any data.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    Widget content;
    if (page == _ViewerPage.academicYear) {
      content = const AdminAcademicYearSettingsScreen();
    } else if (page == _ViewerPage.students) {
      content = const AdminStudentsScreen();
    } else if (page == _ViewerPage.attendance) {
      content = const AdminAttendanceScreen();
    } else if (page == _ViewerPage.parents) {
      content = const AdminParentsScreen();
    } else if (page == _ViewerPage.teachers) {
      content = const AdminTeachersScreen();
    } else if (page == _ViewerPage.classes) {
      content = const AdminClassesSectionsScreen();
    } else if (page == _ViewerPage.timetable) {
      content = const AdminTimetableScreen();
    } else if (page == _ViewerPage.exams) {
      content = const AdminExamsScreen();
    } else if (page == _ViewerPage.homeworkTools) {
      content = const AdminHomeworkMaintenanceScreen();
    } else if (page == _ViewerPage.notifications) {
      content = const NotificationCenterScreen(viewerRole: UserRole.viewer);
    } else {
      // Dashboard page
      content = _ViewerDashboardHome(activeYearId: activeYearId);
    }

    return Column(
      children: [
        banner,
        Expanded(child: content),
      ],
    );
  }
}

class _ViewerDashboardHome extends StatelessWidget {
  const _ViewerDashboardHome({required this.activeYearId});

  final String? activeYearId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.visibility, size: 64, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Viewer Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have read-only access to all school data',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (activeYearId != null)
                      Text(
                        'Academic Year: $activeYearId',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildListDelegate([
              _QuickAccessCard(
                icon: Icons.badge,
                title: 'Students',
                color: Colors.blue,
              ),
              _QuickAccessCard(
                icon: Icons.fact_check_outlined,
                title: 'Attendance',
                color: Colors.green,
              ),
              _QuickAccessCard(
                icon: Icons.school,
                title: 'Exams',
                color: Colors.purple,
              ),
              _QuickAccessCard(
                icon: Icons.family_restroom,
                title: 'Parents',
                color: Colors.orange,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ViewerPage {
  dashboard,
  academicYear,
  students,
  attendance,
  parents,
  teachers,
  classes,
  timetable,
  exams,
  homeworkTools,
  notifications,
}

class _ViewerNavItem {
  const _ViewerNavItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final _ViewerPage page;
}
