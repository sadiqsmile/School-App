import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Needed because background handlers run in their own isolate.

  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Debug prints for runtime Firebase config
  print('[Firebase.app] projectId: \\${app.options.projectId}');
  print('[Firebase.app] apiKey: \\${app.options.apiKey}');
  print('[Firebase.app] authDomain: \\${app.options.authDomain}');
  print('[FirebaseAuth.instance.app] projectId: \\${FirebaseAuth.instance.app.options.projectId}');
  // No UI work here. In-app inbox is powered by Firestore.
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: SchoolApp()));
}