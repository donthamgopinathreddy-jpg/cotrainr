import 'dart:async';

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
import 'services/water_notification_handler.dart';
import 'services/water_notification_platform.dart';
import 'services/water_reminder_service.dart';
import 'widgets/app_link_handler.dart';
import 'widgets/hydration/hydration_lifecycle_refresher.dart';
import 'widgets/privacy/privacy_preferences_sync_initializer.dart';
import 'widgets/quest/quest_sync_initializer.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep OS splash (black + logo) until Flutter paints CotrainrSplashScreen.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Critical startup: Supabase must be ready before GoRouter redirect runs.
  // Branded CotrainrSplashScreen then restores session, loads local prefs,
  // and chooses the initial route (with a short minimum display time).
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Non-blocking secondary services — do not delay first frame / splash.
  final healthService = HealthTrackingService();
  healthService.initialize().then((initialized) {
    if (initialized) {
      debugPrint('Health tracking service initialized successfully');
    } else {
      debugPrint('Health tracking service initialization failed');
    }
  });

  unawaited(_initWaterReminders());
  // Register as early as possible so cold-start notification actions are not dropped.
  WaterNotificationPlatform.ensureQuickLogHandler(
    handler: WaterNotificationHandler.handleActionId,
  );

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _initWaterReminders() async {
  try {
    await WaterReminderService.instance.ensureInitialized();
    await WaterReminderService.instance.rescheduleIfEnabled();
  } catch (e) {
    debugPrint('Water reminder init failed: $e');
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
                  statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      isDark ? Brightness.dark : Brightness.light,
                  systemNavigationBarColor: isDark
                      ? const Color(0xFF000000)
                      : const Color(0xFFFFFFFF),
                  systemNavigationBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarDividerColor: Colors.transparent,
                );
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlay,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: MediaQuery.of(context).textScaler.clamp(
                        minScaleFactor: 0.8,
                        maxScaleFactor: 1.2,
                      ),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
