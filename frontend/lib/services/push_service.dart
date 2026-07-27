import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../navigation.dart';
import 'api_service.dart';

// Real OS/browser push delivery via Firebase Cloud Messaging, kept
// separate from NotificationService (which owns the DB list/mark-read
// calls) since this is purely device-token + FCM plumbing.
class PushService {
  static final Dio _dio = Dio(BaseOptions(baseUrl: ApiService.baseUrl));
  static bool _listenersRegistered = false;

  /// Requests notification permission, retrieves the FCM token, and
  /// registers it with the backend. Called once per login - safe to call
  /// again on a later login (upserts by token server-side).
  static Future<void> registerCurrentDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[PushService] notification permission denied');
        return;
      }

      final token = await messaging.getToken(vapidKey: _vapidKey);
      if (token == null) {
        debugPrint('[PushService] getToken() returned null');
        return;
      }

      final authToken = ApiService.session?.token;
      await _dio.post(
        '/notifications/register-device',
        data: {'token': token, 'platform': 'web'},
        options: Options(
          headers: authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        ),
      );

      _registerListenersOnce();
    } catch (e) {
      debugPrint('[PushService] registerCurrentDevice() failed: $e');
    }
  }

  static void _registerListenersOnce() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    // Foreground messages don't show a native banner on web - the
    // notification row is already written server-side, so it surfaces
    // next time NotificationsScreen is opened/refreshed regardless.
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[PushService] foreground message: ${message.notification?.title}');
    });

    // Tap while the app is backgrounded (not fully closed).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      openRelatedRecord(
        cropId: message.data['cropId'],
        livestockId: message.data['livestockId'],
      );
    });
  }

  // VAPID key from the Firebase console (Project settings -> Cloud
  // Messaging -> Web configuration -> Web Push certificates). Required
  // for FirebaseMessaging.getToken() to work on web.
  static const String _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');
}
