import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_provider.dart';
import 'services/health_tracking_service.dart';
import 'services/push_notification_service.dart';
import 'services/water_notification_handler.dart';
import 'services/water_notification_platform.dart';
import 'services/water_reminder_service.dart';
import 'widgets/app_update/app_version_gate.dart';
import 'widgets/app_link_handler.dart';
import 'widgets/hydration/hydration_lifecycle_refresher.dart';
import 'widgets/privacy/privacy_preferences_sync_initializer.dart';
import 'widgets/quest/quest_sync_initializer.dart';

void _debugLog(String message) {
  if (kDebugMode) debugPrint(message);
}

void main() async {
  _debugLog('[BOOT] app start');
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  _debugLog('[BOOT] widgets binding ready');
  // Keep OS splash until Flutter paints CotrainrSplashScreen (or failsafe).
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Appearance is local-only and cheap to read. Resolve it before runApp so a
  // user who selected Light/Dark does not see a System-theme flash on launch.
  final savedThemeMode = await loadSavedThemeMode();

  try {
    _debugLog('[BOOT] Supabase init start');
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    ).timeout(const Duration(seconds: 12));
    _debugLog('[BOOT] Supabase init complete');
  } catch (e, st) {
    _debugLog('[BOOT] Supabase init failed: $e\n$st');
  }

  // Non-blocking secondary services — do not delay first frame / splash.
  try {
    final healthService = HealthTrackingService();
    unawaited(
      healthService.initialize().then((initialized) {
        if (initialized) {
          _debugLog('Health tracking service initialized successfully');
        } else {
          _debugLog('Health tracking service initialization failed');
        }
      }),
    );
  } catch (e) {
    _debugLog('[BOOT] health init schedule failed: $e');
  }

  unawaited(_initWaterReminders());
  try {
    WaterNotificationPlatform.ensureQuickLogHandler(
      handler: WaterNotificationHandler.onNativeQuickLogApplied,
    );
  } catch (e) {
    _debugLog('[BOOT] water notification handler failed: $e');
  }

  _debugLog('[BOOT] runApp');
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => savedThemeMode),
      ],
      child: const MyApp(),
    ),
  );

  // If CotrainrSplashScreen never paints, do not keep the native logo forever.
  unawaited(
    Future<void>.delayed(const Duration(seconds: 2), () {
      FlutterNativeSplash.remove();
      _debugLog('[BOOT] native splash failsafe remove');
    }),
  );

  widgetsBinding.addPostFrameCallback((_) {
    _debugLog('[BOOT] first frame');
    unawaited(_initPushAfterFirstFrame());
  });
}

Future<void> _initPushAfterFirstFrame() async {
  try {
    await PushNotificationService().initialize();
  } catch (e, st) {
    _debugLog('[BOOT] push after first frame failed: $e\n$st');
  }
}

Future<void> _initWaterReminders() async {
  try {
    await WaterReminderService.instance.ensureInitialized();
    // Heal a dropped alarm chain instead of rescheduling unconditionally:
    // a full reschedule restarts the countdown, so a user who opens the app
    // more often than their interval would never receive a reminder.
    await WaterReminderService.instance.ensureScheduleAlive();
  } catch (e) {
    _debugLog('Water reminder init failed: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return AppLinkHandler(
      child: PrivacyPreferencesSyncInitializer(
        child: QuestSyncInitializer(
          child: HydrationLifecycleRefresher(
            child: AppVersionGate(
              child: MaterialApp.router(
                title: 'Cotrainr',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                routerConfig: appRouter,
                builder: (context, child) {
                  final brightness = Theme.of(context).brightness;
                  final isDark = brightness == Brightness.dark;
                  final overlay = SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: isDark
                        ? Brightness.light
                        : Brightness.dark,
                    statusBarBrightness: isDark
                        ? Brightness.dark
                        : Brightness.light,
                    systemNavigationBarColor: isDark
                        ? const Color(0xFF000000)
                        : const Color(0xFFFFFFFF),
                    systemNavigationBarIconBrightness: isDark
                        ? Brightness.light
                        : Brightness.dark,
                    systemNavigationBarDividerColor: Colors.transparent,
                  );
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: overlay,
                    // Preserve the platform's accessibility text scaling. The
                    // previous 1.2x cap prevented users with larger Android
                    // font settings from receiving their requested text size
                    // and also hid responsive-layout defects during testing.
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
