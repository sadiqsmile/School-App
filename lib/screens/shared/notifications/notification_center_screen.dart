import 'package:flutter/material.dart';

import '../../../models/user_role.dart';
import 'notification_composer_screen.dart';
import 'notification_inbox_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({
    super.key,
    required this.viewerRole,
    this.parentMobile,
    this.initialTab = 0,
  });

  final UserRole viewerRole;
  final String? parentMobile;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    // Parents only get the inbox.
    if (viewerRole == UserRole.parent) {
      return NotificationInboxScreen(viewerRole: viewerRole, parentMobile: parentMobile);
    }

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Material(
              color: Colors.transparent,
              child: TabBar(
                tabs: const [
                  Tab(text: 'Inbox', icon: Icon(Icons.inbox_outlined)),
                  Tab(text: 'Send', icon: Icon(Icons.edit_outlined)),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                indicatorColor: Colors.white,
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: NotificationInboxView(viewerRole: viewerRole, parentMobile: parentMobile),
            ),
            NotificationComposerScreen(viewerRole: viewerRole),
          ],
        ),
      ),
    );
  }
}
