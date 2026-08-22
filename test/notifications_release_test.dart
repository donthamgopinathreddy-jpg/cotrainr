import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cotrainr/services/app_version_service.dart';
import 'package:cotrainr/utils/semantic_version.dart';

void main() {
  group('SemanticVersion', () {
    test('parse and compare semver correctly', () {
      expect(SemanticVersion.parse('1.2.3')!.compareTo(SemanticVersion.parse('1.2.4')!), -1);
      expect(SemanticVersion.parse('2.0.0')!.compareTo(SemanticVersion.parse('1.9.9')!), 1);
      expect(SemanticVersion.parse('1.10.0')!.compareTo(SemanticVersion.parse('1.9.0')!), 1);
    });

    test('does not use lexicographic string compare', () {
      final a = SemanticVersion.parse('1.10.0')!;
      final b = SemanticVersion.parse('1.9.0')!;
      expect('1.10.0'.compareTo('1.9.0') > 0, isFalse);
      expect(a.compareTo(b) > 0, isTrue);
    });
  });

  group('compareInstalledToConfig', () {
    test('equal recommended is up to date', () {
      expect(
        compareInstalledToConfig(
          installedVersion: '1.2.0',
          minimumVersion: '1.0.0',
          recommendedVersion: '1.2.0',
        ),
        VersionCheckOutcome.upToDate,
      );
    });

    test('below recommended but above minimum is optional', () {
      expect(
        compareInstalledToConfig(
          installedVersion: '1.1.0',
          minimumVersion: '1.0.0',
          recommendedVersion: '1.2.0',
        ),
        VersionCheckOutcome.optionalUpdate,
      );
    });

    test('below minimum is required', () {
      expect(
        compareInstalledToConfig(
          installedVersion: '0.9.0',
          minimumVersion: '1.0.0',
          recommendedVersion: '1.2.0',
        ),
        VersionCheckOutcome.requiredUpdate,
      );
    });

    test('installed newer than server recommended is up to date', () {
      expect(
        compareInstalledToConfig(
          installedVersion: '2.0.0',
          minimumVersion: '1.0.0',
          recommendedVersion: '1.2.0',
        ),
        VersionCheckOutcome.upToDate,
      );
    });

    test('malformed config fails open', () {
      expect(
        compareInstalledToConfig(
          installedVersion: '1.0.0',
          minimumVersion: 'bad',
          recommendedVersion: '1.2.0',
        ),
        VersionCheckOutcome.failOpen,
      );
    });
  });

  group('AppVersionService optional dismissal', () {
    test('dismissal keyed by recommended version', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final service = AppVersionService.instance;
      await service.dismissOptionalForVersion('1.3.0');
      final result = AppVersionCheckResult(
        outcome: VersionCheckOutcome.optionalUpdate,
        config: const AppVersionConfig(
          minimumVersion: '1.0.0',
          recommendedVersion: '1.3.0',
        ),
        installedVersion: '1.2.0',
      );
      expect(await service.shouldShowOptionalPrompt(result), isFalse);
    });
  });

  group('push authority contracts', () {
    test('edge functions do not call deliverNotificationRows', () {
      bool documentsWebhookAuthority(String src) {
        return src.contains('notifications_insert_webhook') ||
            src.contains('push_via') ||
            src.contains('webhook send-push-notification') ||
            src.contains('INSERT webhook');
      }

      for (final path in [
        'supabase/functions/create-video-session/index.ts',
        'supabase/functions/respond-video-session/index.ts',
        'supabase/functions/dispatch-video-session-reminders/index.ts',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('deliverNotificationRows'), isFalse, reason: path);
        expect(documentsWebhookAuthority(src), isTrue, reason: path);
      }
    });

    test('send-push-notification is authoritative webhook path', () {
      final src = File('supabase/functions/send-push-notification/index.ts')
          .readAsStringSync();
      expect(src.contains('AUTHORITATIVE PATH'), isTrue);
      expect(src.contains('deliverNotificationPush'), isTrue);
    });

    test('migration unschedules pg_cron and documents authorities', () {
      final sql = File('supabase/migrations/20260824_notifications_release.sql')
          .readAsStringSync();
      expect(sql.contains("cron.unschedule('cotrainr-video-session-reminders')"), isTrue);
      expect(sql.contains('push_delivery_authority'), isTrue);
      expect(sql.contains('get_app_version_config'), isTrue);
    });
  });

  group('logout and token lifecycle contracts', () {
    test('settings logout uses NotificationSessionCleanup before signOut', () {
      final src = File('lib/pages/profile/settings_page.dart').readAsStringSync();
      final logout = src.substring(src.indexOf('_handleLogout'));
      expect(logout.contains('NotificationSessionCleanup.prepareForLogout'), isTrue);
      expect(
        logout.indexOf('prepareForLogout'),
        lessThan(logout.indexOf('auth.signOut')),
      );
    });

    test('push service decouples initial message from token register', () {
      final src = File('lib/services/push_notification_service.dart').readAsStringSync();
      expect(src.contains('_processInitialMessage'), isTrue);
      expect(src.contains('unawaited(_processInitialMessage())'), isTrue);
      final registerMatch = RegExp(
        r'Future<void> _registerTokenIfPermitted\(\) async \{([\s\S]*?)\n  \}',
      ).firstMatch(src);
      expect(registerMatch, isNotNull);
      expect(registerMatch!.group(1)!.contains('getInitialMessage'), isFalse);
    });

    test('invalid token cleanup in push_deliver', () {
      final src = File('supabase/functions/_shared/push_deliver.ts').readAsStringSync();
      expect(src.contains('permanentTokenFailure'), isTrue);
      expect(src.contains('device_token_removed'), isTrue);
    });

    test('pending navigation cleared on logout path', () {
      final cleanup = File('lib/services/notification_session_cleanup.dart')
          .readAsStringSync();
      expect(cleanup.contains('VideoSessionPendingNavigation.clear'), isTrue);
      expect(cleanup.contains('removeDeviceToken'), isTrue);
    });
  });

  group('settings resume registers token', () {
    test('notifications page registers token when OS permission granted', () {
      final src = File('lib/pages/profile/settings/notifications_page.dart')
          .readAsStringSync();
      expect(src.contains('registerToken'), isTrue);
      expect(src.contains('OsNotificationAccessLabel.allowed'), isTrue);
    });
  });

  group('duplicate reminder scheduler idempotency', () {
    test('dispatch locks jobs and marks sent_at once', () {
      final sql = File(
        'supabase/migrations/20260822_video_session_attendance_reminders.sql',
      ).readAsStringSync();
      expect(sql.contains('FOR UPDATE SKIP LOCKED'), isTrue);
      expect(sql.contains('SET sent_at = NOW()'), isTrue);
      expect(sql.contains('ON CONFLICT DO NOTHING'), isTrue);
    });
  });

  group('account switch safety', () {
    test('home shell clears pending video route on auth change', () {
      final src = File('lib/pages/home/home_shell_page.dart').readAsStringSync();
      expect(src.contains('onAuthStateChange'), isTrue);
      expect(src.contains('VideoSessionPendingNavigation.clear'), isTrue);
      expect(src.contains('invalidate(unreadNotificationsCountProvider)'), isTrue);
    });
  });

  group('water reminder lifecycle', () {
    test('logout cancels water reminders and sign-in reschedules', () {
      final cleanup = File('lib/services/notification_session_cleanup.dart')
          .readAsStringSync();
      expect(cleanup.contains('WaterReminderService.instance.cancelAll'), isTrue);
      expect(cleanup.contains('rescheduleIfEnabled'), isTrue);
    });
  });

  group('app version gate contracts', () {
    test('checks on startup and resume', () {
      final src = File('lib/widgets/app_update/app_version_gate.dart').readAsStringSync();
      expect(src.contains('didChangeAppLifecycleState'), isTrue);
      expect(src.contains('RequiredUpdateScreen'), isTrue);
      expect(src.contains('showOptionalUpdateDialog'), isTrue);
    });

    test('offline uses cached minimum in service', () {
      final src = File('lib/services/app_version_service.dart').readAsStringSync();
      expect(src.contains('_cachedMinimumKey'), isTrue);
      expect(src.contains('VersionCheckOutcome.failOpen'), isTrue);
    });
  });

  group('legacy social hidden', () {
    test('CoCircle and Quest notifications gated by feature flags', () {
      final repo = File('lib/repositories/notifications_repository.dart')
          .readAsStringSync();
      expect(repo.contains('FeatureFlags.communityNotificationsActive'), isTrue);
      expect(repo.contains('FeatureFlags.questNotificationsActive'), isTrue);
    });
  });

  group('transient FCM errors', () {
    test('only permanent failures delete device tokens', () {
      final src = File('supabase/functions/_shared/push_deliver.ts').readAsStringSync();
      expect(src.contains('} else if (result.permanentTokenFailure)'), isTrue);
      expect(src.contains('permanent_token_failure'), isTrue);
    });
  });
}
