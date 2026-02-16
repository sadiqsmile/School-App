import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'router/app_router.dart';
import 'providers/core_providers.dart';

class SchoolApp extends ConsumerWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    // Initialize local notification channel + foreground handlers once per app lifecycle.
    ref.listen<AsyncValue<void>>(
      _notificationInitProvider,
      (previous, next) {},
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'School App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      routerConfig: router,
    );
  }
}

final _notificationInitProvider = FutureProvider<void>((ref) async {
  await ref.read(notificationLocalServiceProvider).init();

  // Foreground messages: show a local notification (Android). For web, rely on browser notifications.
  FirebaseMessaging.onMessage.listen((message) async {
    final n = message.notification;
    if (n == null) return;

    await ref.read(notificationLocalServiceProvider).showForeground(
          title: n.title ?? 'Notification',
          body: n.body ?? '',
        );
  });
});
