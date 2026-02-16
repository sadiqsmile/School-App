import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';

/// Invisible widget that registers the device FCM token into Firestore.
///
/// Place this inside dashboards after login/session is known.
class NotificationTokenRegistrationRunner extends ConsumerStatefulWidget {
  const NotificationTokenRegistrationRunner.user({
    super.key,
    required this.uid,
    this.vapidKey,
  })  : parentMobile = null,
        _mode = _Mode.user;

  const NotificationTokenRegistrationRunner.parent({
    super.key,
    required this.parentMobile,
    this.vapidKey,
  })  : uid = null,
        _mode = _Mode.parent;

  final String? uid;
  final String? parentMobile;

  /// Web Push VAPID key (Firebase Console → Cloud Messaging → Web configuration).
  ///
  /// You can pass it here or keep it null if you only target Android for now.
  final String? vapidKey;

  final _Mode _mode;

  @override
  ConsumerState<NotificationTokenRegistrationRunner> createState() =>
      _NotificationTokenRegistrationRunnerState();
}

enum _Mode { user, parent }

class _NotificationTokenRegistrationRunnerState
    extends ConsumerState<NotificationTokenRegistrationRunner> {
  bool _didRun = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _runOnce();
  }

  @override
  void didUpdateWidget(covariant NotificationTokenRegistrationRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Allow re-run if identity changes.
    final oldKey = '${oldWidget._mode}:${oldWidget.uid ?? oldWidget.parentMobile ?? ''}';
    final newKey = '${widget._mode}:${widget.uid ?? widget.parentMobile ?? ''}';
    if (oldKey != newKey) {
      _didRun = false;
      _runOnce();
    }
  }

  Future<void> _runOnce() async {
    if (_didRun) return;

    final uid = widget.uid?.trim() ?? '';
    final mobile = widget.parentMobile?.trim() ?? '';

    if (widget._mode == _Mode.user && uid.isEmpty) return;
    if (widget._mode == _Mode.parent && mobile.isEmpty) return;

    _didRun = true;

    try {
      // Keep this silent; dashboards shouldn’t spam snackbars for permissions.
      final svc = ref.read(notificationTokenServiceProvider);
      if (widget._mode == _Mode.user) {
        await svc.registerUserToken(uid: uid, vapidKey: widget.vapidKey);
      } else {
        await svc.registerParentToken(parentMobile: mobile, vapidKey: widget.vapidKey);
      }
    } catch (e) {
      // If Firestore rules block (common for parent session without FirebaseAuth),
      // ignore so app continues to work.
      if (kDebugMode) {
        // ignore: avoid_print
        print('FCM token registration failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
