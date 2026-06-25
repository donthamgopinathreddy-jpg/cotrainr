import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import 'water_intake_service.dart';

/// Action IDs for water reminder notification buttons.
abstract final class WaterNotificationActions {
  static const add250 = 'water_add_250';
  static const add500 = 'water_add_500';

  static const androidActions = <AndroidNotificationAction>[
    AndroidNotificationAction(
      add250,
      '+250 ml',
      titleColor: Color(0xFF2FC8FF),
      showsUserInterface: false,
    ),
    AndroidNotificationAction(
      add500,
      '+500 ml',
      titleColor: Color(0xFF2FC8FF),
      showsUserInterface: false,
    ),
  ];
}

@pragma('vm:entry-point')
void waterNotificationBackgroundResponse(NotificationResponse response) {
  WaterNotificationHandler.handle(response);
}

/// Handles water reminder notification action taps (foreground + background).
class WaterNotificationHandler {
  static Future<void> onForegroundResponse(
    NotificationResponse response,
  ) async {
    await handle(response);
  }

  static Future<void> handle(NotificationResponse response) async {
    final liters = litersForActionId(response.actionId);
    if (liters == null) return;

    await _ensureSupabaseReady();
    await WaterIntakeService.instance.addWater(liters);
  }

  static double? litersForActionId(String? actionId) {
    return switch (actionId) {
      WaterNotificationActions.add250 => 0.25,
      WaterNotificationActions.add500 => 0.5,
      _ => null,
    };
  }

  static Future<void> _ensureSupabaseReady() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      Supabase.instance.client;
      return;
    } catch (_) {
      // Not initialized yet (background isolate).
    }
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }
}
