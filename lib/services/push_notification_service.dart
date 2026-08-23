import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/app_router.dart';
import '../video_sessions/video_session_notification_logic.dart';
import 'active_conversation_tracker.dart';
import 'local_notification_router.dart';
import 'message_notification_actions.dart';
import 'notification_session_cleanup.dart';
import 'video_session_notification_actions.dart';

/// Top-level isolate entry for FCM. Must stay a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[BOOT] FCM background Firebase init failed: $e');
  }
  await showVideoSessionReminderIfNeeded(message);
}

Future<void> showVideoSessionReminderIfNeeded(RemoteMessage message) async {
  final data = message.data;
  final type = data['type'] ?? data['notification_type'] ?? '';
  if (!VideoSessionNotificationLogic.isActionableReminderType(type.toString())) {
    return;
  }
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveBackgroundNotificationResponse:
        localNotificationBackgroundRouter,
  );
  if (Platform.isAndroid) {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        VideoSessionNotificationActions.channelId,
        'Video Sessions',
        description: 'Video session reminders and start alerts',
        importance: Importance.max,
      ),
    );
  }
  await _showActionableVideoLocalNotification(plugin, data);
}

Future<void> _showActionableVideoLocalNotification(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> data,
) async {
  final sessionId = VideoSessionNotificationActions.sessionIdFrom(data) ?? '';
  final type = data['type']?.toString() ??
      data['notification_type']?.toString() ??
      '';
  final id = Object.hash(sessionId, type) & 0x7fffffff;
  final title = data['title']?.toString().trim().isNotEmpty == true
      ? data['title'].toString()
      : VideoSessionNotificationActions.reminderTitleFromData(data);
  final body = VideoSessionNotificationActions.reminderBodyFromData(data);
  final payload = VideoSessionNotificationActions.encodePayload(
    action: 'open',
    sessionId: sessionId,
    joinUrl: data['join_url']?.toString(),
    scheduledStart: data['scheduled_start']?.toString(),
    durationMinutes: int.tryParse('${data['duration_minutes']}'),
    status: data['status']?.toString() ?? 'scheduled',
    type: type,
    counterpartName: data['counterpart_name']?.toString(),
  );
  await plugin.show(
    id == 0 ? type.hashCode : id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        VideoSessionNotificationActions.channelId,
        'Video Sessions',
        channelDescription: 'Video session reminders and start alerts',
        importance: Importance.max,
        priority: Priority.max,
        actions: VideoSessionNotificationActions.androidActions,
      ),
    ),
    payload: payload,
  );
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  static PushNotificationService get instance => _instance;
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
            onDidReceiveBackgroundNotificationResponse:
                localNotificationBackgroundRouter,
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

      _authSub ??=
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          unawaited(NotificationSessionCleanup.onAccountSignedIn());
        }
      });

      unawaited(_consumeLaunchIntents());
      unawaited(_processInitialMessage());
      unawaited(_registerTokenIfPermitted());
      debugPrint('[BOOT] push init complete');
    } catch (e, st) {
      debugPrint('[BOOT] push init failed: $e\n$st');
    }
  }

  Future<void> _consumeLaunchIntents() async {
    try {
      final launch = await _localNotifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true &&
          launch?.notificationResponse != null) {
        _onNotificationTapped(launch!.notificationResponse!);
      }
    } catch (e) {
      debugPrint('[BOOT] launch notification details failed: $e');
    }
  }

  /// Cold-start FCM tap — independent of permission/token registration.
  Future<void> _processInitialMessage() async {
    try {
      final messaging = _messaging;
      if (messaging == null) return;
      final initial = await messaging.getInitialMessage().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
      if (initial != null) {
        _handleNotificationTap(initial);
      }
    } catch (e) {
      debugPrint('[BOOT] initial message handling failed: $e');
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
        debugPrint(
          '[BOOT] skip FCM token; permission=${settings.authorizationStatus}',
        );
        return;
      }
      final token = await messaging.getToken().timeout(const Duration(seconds: 8));
      if (token != null) await saveDeviceToken(token);
    } catch (e) {
      debugPrint('[BOOT] FCM token/register skipped: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (routeLocalNotificationResponse(response)) return;
    appRouter.go('/notifications');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final data = message.data;
    final type = (data['type'] ?? data['notification_type'] ?? '').toString();
    final isActionable =
        VideoSessionNotificationLogic.isActionableReminderType(type);
    if (isActionable) {
      await _showActionableVideoLocalNotification(_localNotifications, data);
      return;
    }

    if (MessageNotificationActions.isMessageType(type)) {
      final conversationId =
          MessageNotificationActions.conversationIdFrom(data);
      if (conversationId != null &&
          ActiveConversationTracker.instance.isActive(conversationId)) {
        return;
      }
      final notification = message.notification;
      final rawTitle =
          (notification?.title ?? data['title']?.toString() ?? '').trim();
      final title = rawTitle.isNotEmpty ? rawTitle : 'New message';
      final body = notification?.body ?? data['body']?.toString() ?? '';
      final payload = MessageNotificationActions.encodePayload(
        conversationId: conversationId ?? '',
        type: type,
      );
      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Cotrainr Notifications',
            channelDescription: 'Push notifications from Cotrainr',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: payload,
      );
      return;
    }

    final notification = message.notification;
    if (notification == null) return;
    final isVideo = type.startsWith('video_session_');
    final payload = jsonEncode({
      'action': 'open',
      'type': type,
      'video_session_id': data['video_session_id'],
      'join_url': data['join_url'],
      'scheduled_start': data['scheduled_start'],
      'status': data['status'] ?? 'scheduled',
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
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? data['notification_type'] ?? '').toString();
    if (MessageNotificationActions.isMessageType(type)) {
      MessageNotificationActions.routeFromPushData(data);
      return;
    }
    VideoSessionNotificationActions.routeFromPushData(data);
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
          '[BOOT] device_tokens table missing — apply migrations',
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
