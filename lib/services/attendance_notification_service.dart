import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/app_config.dart';

/// Service for sending attendance-related notifications
class AttendanceNotificationService {
  AttendanceNotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  DocumentReference<Map<String, dynamic>> _schoolDoc({
    String schoolId = AppConfig.schoolId,
  }) {
    return _firestore.collection('schools').doc(schoolId);
  }

  // ============================================================================
  // PARENT NOTIFICATIONS FOR ABSENT STUDENTS
  // ============================================================================

  /// Send notification to parent when student is marked absent
  Future<void> sendAbsentNotification({
    required String schoolId,
    required String studentId,
    required String studentName,
    required DateTime date,
  }) async {
    try {
      // Get parent device tokens
      final tokens = await _getParentTokens(schoolId, studentId);
      
      if (tokens.isEmpty) {
        return; // No tokens, skip
      }

      // Format date
      final dateStr = '${date.day}/${date.month}/${date.year}';

      // Send notification to each token
      for (final token in tokens) {
        await _sendPushNotification(
          token: token,
          title: 'Absence Alert',
          body: '$studentName was marked absent on $dateStr.',
          data: {
            'type': 'attendance_absent',
            'studentId': studentId,
            'date': date.toIso8601String(),
          },
        );
      }

      // Log notification
      await _logNotification(
        schoolId: schoolId,
        studentId: studentId,
        type: 'absent',
        message: 'Student marked absent on $dateStr',
      );
    } catch (e) {
      // Fail silently - don't block attendance marking
      print('Error sending absent notification: $e');
    }
  }

  // ============================================================================
  // CONSECUTIVE ABSENT ALERTS
  // ============================================================================

  /// Send alert when student has 3+ consecutive absents
  Future<void> sendConsecutiveAbsentAlert({
    required String schoolId,
    required String studentId,
    required String studentName,
    required int consecutiveDays,
  }) async {
    try {
      // Get parent tokens
      final parentTokens = await _getParentTokens(schoolId, studentId);

      // Get teacher/admin tokens
      final staffTokens = await _getStaffTokens(schoolId);

      final allTokens = [...parentTokens, ...staffTokens];
      
      if (allTokens.isEmpty) {
        return;
      }

      // Send to all relevant parties
      for (final token in allTokens) {
        await _sendPushNotification(
          token: token,
          title: '⚠️ Consecutive Absence Alert',
          body: '$studentName has been absent for $consecutiveDays consecutive days.',
          data: {
            'type': 'consecutive_absent_alert',
            'studentId': studentId,
            'consecutiveDays': consecutiveDays.toString(),
            'priority': 'high',
          },
        );
      }

      // Log alert
      await _logNotification(
        schoolId: schoolId,
        studentId: studentId,
        type: 'consecutive_absent_alert',
        message: '$consecutiveDays consecutive absents',
      );
    } catch (e) {
      print('Error sending consecutive absent alert: $e');
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get parent device tokens for a student
  Future<List<String>> _getParentTokens(
    String schoolId,
    String studentId,
  ) async {
    try {
      // Get student document to find parent ID
      final studentDoc = await _schoolDoc(schoolId: schoolId)
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        return [];
      }

      final parentIds = <String>[];
      
      // Handle single parent
      final parentId = studentDoc.data()?['parentId'] as String?;
      if (parentId != null) {
        parentIds.add(parentId);
      }

      // Handle multiple parents
      final parentIdsList = studentDoc.data()?['parentIds'] as List?;
      if (parentIdsList != null) {
        parentIds.addAll(parentIdsList.whereType<String>());
      }

      // Get tokens for all parents
      final tokens = <String>[];
      
      for (final pId in parentIds) {
        final parentDoc = await _schoolDoc(schoolId: schoolId)
            .collection('users')
            .doc(pId)
            .get();

        if (parentDoc.exists) {
          final token = parentDoc.data()?['fcmToken'] as String?;
          final parentToken = parentDoc.data()?['parentToken'] as String?;
          
          if (token != null) tokens.add(token);
          if (parentToken != null) tokens.add(parentToken);
        }
      }

      return tokens;
    } catch (e) {
      print('Error getting parent tokens: $e');
      return [];
    }
  }

  /// Get staff (teacher/admin) device tokens
  Future<List<String>> _getStaffTokens(String schoolId) async {
    try {
      final tokens = <String>[];
      
      // Get all admins and teachers
      final staffSnapshot = await _schoolDoc(schoolId: schoolId)
          .collection('users')
          .where('role', whereIn: ['admin', 'teacher'])
          .get();

      for (final doc in staffSnapshot.docs) {
        final token = doc.data()['fcmToken'] as String?;
        if (token != null) {
          tokens.add(token);
        }
      }

      return tokens;
    } catch (e) {
      print('Error getting staff tokens: $e');
      return [];
    }
  }

  /// Send push notification using FCM
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // In production, this would call your Firebase Cloud Functions
      // or use Firebase Admin SDK from backend
      
      // For now, store in Firestore for background function to process
      await _firestore.collection('notifications_queue').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('Error queueing notification: $e');
    }
  }

  /// Log notification to Firestore
  Future<void> _logNotification({
    required String schoolId,
    required String studentId,
    required String type,
    required String message,
  }) async {
    try {
      await _schoolDoc(schoolId: schoolId)
          .collection('notification_logs')
          .add({
        'studentId': studentId,
        'type': type,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging notification: $e');
    }
  }

  // ============================================================================
  // BATCH NOTIFICATIONS
  // ============================================================================

  /// Send batch notifications for multiple absent students
  Future<void> sendBatchAbsentNotifications({
    required String schoolId,
    required Map<String, String> absentStudents, // studentId -> studentName
    required DateTime date,
  }) async {
    for (final entry in absentStudents.entries) {
      await sendAbsentNotification(
        schoolId: schoolId,
        studentId: entry.key,
        studentName: entry.value,
        date: date,
      );
    }
  }

  // ============================================================================
  // DEVICE TOKEN MANAGEMENT
  // ============================================================================

  /// Update user's FCM token
  Future<void> updateUserToken({
    required String schoolId,
    required String userId,
    required String token,
  }) async {
    try {
      await _schoolDoc(schoolId: schoolId)
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  /// Initialize notifications for current user
  Future<void> initializeNotifications(String userId, String schoolId) async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get token
        final token = await _messaging.getToken();
        if (token != null) {
          await updateUserToken(
            schoolId: schoolId,
            userId: userId,
            token: token,
          );
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          updateUserToken(
            schoolId: schoolId,
            userId: userId,
            token: newToken,
          );
        });
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }
}
