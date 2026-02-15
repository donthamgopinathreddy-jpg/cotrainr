import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';

/// Handles FCM push notifications: init, token registration, foreground/background handlers.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.notification?.title}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'cotrainr_notifications';

  /// Initialize Firebase and push notifications. Call from main() after Supabase init.
  /// Requires google-services.json (Android) and GoogleService-Info.plist (iOS).
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        // Uses default from google-services.json / GoogleService-Info.plist
        // Add those files from Firebase Console to enable push
      );
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Create Android notification channel for FCM
      if (Platform.isAndroid) {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidSettings);
        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                _channelId,
                'Cotrainr Notifications',
                description: 'Push notifications from Cotrainr',
                importance: Importance.high,
              ),
            );
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push permission denied');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) await saveDeviceToken(token);

      _messaging.onTokenRefresh.listen(saveDeviceToken);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    } catch (e) {
      debugPrint('PushNotificationService init error: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    appRouter.go('/notifications');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      message.hashCode,
      notification.title ?? 'Cotrainr',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Cotrainr Notifications',
          channelDescription: 'Push notifications from Cotrainr',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'meeting' && data['meeting_id'] != null) {
      // Could navigate to meeting - handled by app link or deep link
    }
    // Defer navigation until app is built (for getInitialMessage)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.go('/notifications');
    });
  }

  /// Re-register token (fetch current and save). Call after user signs in.
  Future<void> registerToken() async {
    final token = await _messaging.getToken();
    await saveDeviceToken(token);
  }

  /// Save FCM token to Supabase device_tokens.
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
    }
  }

  /// Remove token on sign out.
  Future<void> removeDeviceToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final token = await _messaging.getToken();
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
