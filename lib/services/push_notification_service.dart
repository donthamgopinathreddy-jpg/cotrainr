import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/app_router.dart';
import 'video_session_notification_actions.dart';

/// Top-level isolate entry for FCM. Must stay a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[BOOT] FCM background Firebase init failed: $e');
  }
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _started = false;
  StreamSubscription<AuthState>? _authSub;

  static const String _channelId = 'cotrainr_notifications';

  /// Never throws. Never call before the first Flutter frame.
  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    debugPrint('[BOOT] push init start');
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      debugPrint('[BOOT] Firebase.initializeApp complete');

      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('[BOOT] onBackgroundMessage register failed: $e');
      }

      _messaging = FirebaseMessaging.instance;

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );
      await _localNotifications
          .initialize(
            initSettings,
            onDidReceiveNotificationResponse: _onNotificationTapped,
          )
          .timeout(const Duration(seconds: 5));

      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Cotrainr Notifications',
            description: 'Push notifications from Cotrainr',
            importance: Importance.high,
          ),
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            VideoSessionNotificationActions.channelId,
            'Video Sessions',
            description: 'Video session reminders and start alerts',
            importance: Importance.max,
          ),
        );
      }

      _messaging!.onTokenRefresh.listen(saveDeviceToken);
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _authSub ??= Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          unawaited(_registerTokenIfPermitted());
        }
      });

      unawaited(_registerTokenIfPermitted());
      debugPrint('[BOOT] push init complete');
    } catch (e, st) {
      debugPrint('[BOOT] push init failed: $e\n$st');
    }
  }

  Future<void> _registerTokenIfPermitted() async {
    try {
      final messaging = _messaging;
      if (messaging == null) return;
      final settings = await messaging.getNotificationSettings().timeout(
            const Duration(seconds: 4),
          );
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint('[BOOT] skip FCM token; permission=${settings.authorizationStatus}');
        return;
      }
      final initial = await messaging.getInitialMessage().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
      if (initial != null) _handleNotificationTap(initial);
      final token = await messaging.getToken().timeout(const Duration(seconds: 8));
      if (token != null) await saveDeviceToken(token);
    } catch (e) {
      debugPrint('[BOOT] FCM token/register skipped: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload =
        VideoSessionNotificationActions.decodePayload(response.payload);
    if (payload != null &&
        (payload.containsKey('video_session_id') ||
            response.actionId == VideoSessionNotificationActions.join ||
            response.actionId == VideoSessionNotificationActions.dismiss)) {
      VideoSessionNotificationActions.handleResponse(response);
      return;
    }
    appRouter.go('/notifications');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;
    final data = message.data;
    final type = data['type'] ?? '';
    final isVideo = type.toString().startsWith('video_session_');
    final isActionable = type == 'video_session_reminder_5m' ||
        type == 'video_session_starting';
    final payload = jsonEncode({
      'action': 'open',
      'type': type,
      'video_session_id': data['video_session_id'],
      'join_url': data['join_url'],
      'scheduled_start': data['scheduled_start'],
      'status': 'scheduled',
    });

    await _localNotifications.show(
      message.hashCode,
      notification.title ?? 'Cotrainr',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          isVideo ? VideoSessionNotificationActions.channelId : _channelId,
          isVideo ? 'Video Sessions' : 'Cotrainr Notifications',
          channelDescription: isVideo
              ? 'Video session reminders and start alerts'
              : 'Push notifications from Cotrainr',
          importance: isActionable ? Importance.max : Importance.high,
          priority: isActionable ? Priority.max : Priority.high,
          actions: isActionable
              ? const [
                  AndroidNotificationAction(
                    VideoSessionNotificationActions.join,
                    'Join',
                    showsUserInterface: true,
                  ),
                  AndroidNotificationAction(
                    VideoSessionNotificationActions.dismiss,
                    'Dismiss',
                    cancelNotification: true,
                  ),
                ]
              : null,
        ),
      ),
      payload: payload,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    VideoSessionNotificationActions.routeFromPushData(message.data);
  }

  Future<void> registerToken() async {
    try {
      await initialize();
      final token = await _messaging?.getToken().timeout(
            const Duration(seconds: 8),
          );
      await saveDeviceToken(token);
    } catch (e) {
      debugPrint('[BOOT] registerToken failed: $e');
    }
  }

  Future<void> saveDeviceToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await Supabase.instance.client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
    } catch (e) {
      debugPrint('Error saving device token: $e');
      if (e is PostgrestException && e.code == 'PGRST205') {
        debugPrint(
          '[BOOT] device_tokens table missing — apply migration '
          '20260821_video_session_names_and_push.sql',
        );
      }
    }
  }

  Future<void> removeDeviceToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final token = await _messaging?.getToken();
      if (token != null) {
        await Supabase.instance.client
            .from('device_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', token);
      }
    } catch (e) {
      debugPrint('Error removing device token: $e');
    }
  }
}
