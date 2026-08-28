import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static source-contract tests for backend security guarantees that cannot be
/// exercised against hosted Supabase from a local Flutter test run. Each test
/// pins an invariant that a future edit could silently regress.

String _read(String path) => File(path).readAsStringSync();

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  group('create_notification is not client-callable', () {
    final migration =
        _read('supabase/migrations/20260828_notification_security_hardening.sql');

    test('no Flutter code calls the RPC', () {
      for (final file in _dartFiles('lib')) {
        expect(
          file.readAsStringSync().contains('create_notification'),
          isFalse,
          reason: '${file.path} calls create_notification; it is server-only',
        );
      }
    });

    test('migration revokes execute from anon, authenticated and PUBLIC', () {
      for (final role in const ['FROM PUBLIC', 'FROM anon', 'FROM authenticated']) {
        expect(migration.contains(role), isTrue,
            reason: 'missing REVOKE ... $role');
      }
      expect(migration.contains('REVOKE ALL ON FUNCTION public.create_notification'),
          isTrue);
    });

    test('migration keeps the trusted service_role path', () {
      expect(
        migration.contains(
            'GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB)\n  TO service_role'),
        isTrue,
      );
    });

    test('function keeps a safe search_path and rejects client roles', () {
      expect(migration.contains('SET search_path = public, pg_temp'), isTrue);
      expect(migration.contains("v_role IN ('anon', 'authenticated')"), isTrue);
      expect(migration.contains("ERRCODE = '42501'"), isTrue);
    });

    test('historical notification migration is left untouched', () {
      final legacy = _read('supabase/migrations/20250213_notification_system.sql');
      expect(legacy.contains('CREATE OR REPLACE FUNCTION public.create_notification'),
          isTrue);
      expect(legacy.contains('REVOKE'), isFalse);
    });
  });

  group('send-push-notification authenticates its caller', () {
    final src = _read('supabase/functions/send-push-notification/index.ts');

    test('uses a dedicated secret, not a reused key', () {
      expect(src.contains('NOTIFICATION_WEBHOOK_SECRET'), isTrue);
      expect(src.contains('SERVICE_ROLE'), isFalse);
      expect(src.contains('SUPABASE_ANON_KEY'), isFalse);
    });

    test('fails closed when the secret env var is absent', () {
      expect(src.contains('if (!expectedSecret)'), isTrue);
      expect(src.contains('configuration_error'), isTrue);
      expect(src.contains('503'), isTrue);
    });

    test('rejects a missing or wrong caller secret with 401', () {
      expect(src.contains('x-notification-webhook-secret'), isTrue);
      expect(src.contains('secretsMatch'), isTrue);
      expect(src.contains("json({ error: \"unauthorized\" }, 401)"), isTrue);
    });

    test('authenticates before parsing the payload', () {
      expect(src.indexOf('secretsMatch') < src.indexOf('req.json()'), isTrue,
          reason: 'caller must be authenticated before the body is read');
    });

    test('validates the webhook payload shape', () {
      final payload = _read('supabase/functions/send-push-notification/payload.ts');
      for (final field in const ['id', 'user_id', 'type', 'title', 'body']) {
        expect(payload.contains('"$field"'), isTrue);
      }
      expect(payload.contains('"public"'), isTrue);
      expect(payload.contains('"INSERT"'), isTrue);
      expect(payload.contains('"notifications"'), isTrue);
      expect(src.contains('invalid_payload'), isTrue);
      expect(src.contains('400'), isTrue);
    });

    test('does not log secrets, bodies or tokens', () {
      // Collect every line inside a console.* call by tracking bracket depth.
      final logged = <String>[];
      var depth = 0;
      for (final line in src.split('\n')) {
        if (depth == 0 && !RegExp(r'console\.(log|warn|error)\(').hasMatch(line)) {
          continue;
        }
        logged.add(line);
        depth += '('.allMatches(line).length - ')'.allMatches(line).length;
        if (depth <= 0) depth = 0;
      }
      expect(logged, isNotEmpty, reason: 'log scan found nothing to check');

      final loggedSrc = logged.join('\n');
      for (final forbidden in const [
        'expectedSecret',
        'req.headers',
        'validated.record',
        'record.body',
        'token',
      ]) {
        expect(loggedSrc.contains(forbidden), isFalse,
            reason: 'log statement leaks "$forbidden"');
      }
    });
  });

  group('dispatch-video-session-reminders fails closed', () {
    final src =
        _read('supabase/functions/dispatch-video-session-reminders/index.ts');

    test('the cron secret is mandatory', () {
      expect(src.contains('if (!cronSecret)'), isTrue);
      expect(src.contains('configuration_error'), isTrue);
      expect(src.contains('503'), isTrue);
      expect(src.contains('if (cronSecret) {'), isFalse,
          reason: 'the old fail-open conditional must be gone');
    });

    test('missing or wrong caller secret returns 401', () {
      expect(src.contains('secretsMatch(cronSecret'), isTrue);
      expect(src.contains('401'), isTrue);
    });

    test('no service-role client is created before authentication', () {
      expect(src.indexOf('secretsMatch(cronSecret') <
          src.indexOf('SUPABASE_SERVICE_ROLE_KEY'), isTrue);
      expect(src.indexOf('if (!cronSecret)') < src.indexOf('createClient('), isTrue);
    });

    test('the privileged RPC is unchanged', () {
      expect(src.contains('dispatch_video_session_notification_jobs'), isTrue);
    });
  });

  group('dormant Zoom OAuth is decommissioned', () {
    test('zoom edge functions are removed from source', () {
      for (final path in const [
        'supabase/functions/zoom-oauth-start/index.ts',
        'supabase/functions/zoom-oauth-callback/index.ts',
        'supabase/functions/zoom-disconnect/index.ts',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: '$path should be deleted');
      }
    });

    test('no Flutter code invokes a Zoom edge function', () {
      for (final file in _dartFiles('lib')) {
        final src = file.readAsStringSync();
        expect(src.contains('zoom-oauth'), isFalse, reason: file.path);
        expect(src.contains('zoom-disconnect'), isFalse, reason: file.path);
      }
    });

    test('config.toml no longer configures Zoom functions', () {
      final config = _read('supabase/config.toml');
      expect(config.contains('[functions.zoom-oauth-start]'), isFalse);
      expect(config.contains('[functions.zoom-oauth-callback]'), isFalse);
      expect(config.contains('[functions.zoom-disconnect]'), isFalse);
    });

    test('the Zoom deploy runbook is marked decommissioned', () {
      final doc = _read('docs/VIDEO_SESSIONS_EDGE_FUNCTIONS.md');
      expect(doc.contains('DECOMMISSIONED'), isTrue);
      expect(doc.contains('DO NOT DEPLOY'), isTrue);
      expect(doc.contains('supabase functions delete zoom-oauth-start'), isTrue);
    });
  });

  group('verify_jwt = false functions each document their own auth', () {
    final config = _read('supabase/config.toml');

    test('every unauthenticated function is listed and justified', () {
      for (final fn in const [
        'login-with-identifier',
        'google-oauth-callback',
        'dispatch-video-session-reminders',
        'send-push-notification',
      ]) {
        expect(config.contains('[functions.$fn]'), isTrue,
            reason: '$fn must be declared in config.toml');
      }
      expect(config.contains('verify_jwt = false'), isTrue);
      expect(config.contains('respond-video-session'), isTrue);
    });

    test('google OAuth callback still relies on state + PKCE', () {
      final src = _read('supabase/functions/google-oauth-callback/index.ts');
      expect(src.contains('oauth_pending_states'), isTrue);
      expect(src.contains('code_verifier'), isTrue);
      expect(src.contains('invalid_state'), isTrue);
      expect(src.contains('state_expired'), isTrue);
    });
  });

  group('push architecture is unchanged', () {
    test('FCM delivery is only reached from the notifications webhook', () {
      final callers = Directory('supabase/functions')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.ts'))
          .where((f) => f.readAsStringSync().contains('deliverNotificationPush'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();

      expect(
        callers.every((p) =>
            p.endsWith('_shared/push_deliver.ts') ||
            p.endsWith('send-push-notification/index.ts')),
        isTrue,
        reason: 'unexpected FCM delivery caller(s): $callers',
      );
    });

    test('Flutter never sends FCM directly', () {
      for (final file in _dartFiles('lib')) {
        expect(file.readAsStringSync().contains('fcm.googleapis.com'), isFalse,
            reason: file.path);
      }
    });
  });
}
