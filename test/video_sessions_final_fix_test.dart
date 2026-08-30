// Video sessions final fix pass.
//
// Covers:
//   - sanitized user-facing errors (session load, create, disconnect, cancel)
//   - internal OAuth callback slugs mapped to human copy
//   - group sessions never labelled "Rejected" because one invitee declined
//   - one decline never disables Join for anyone else
//   - per-participant response state
//   - a failed Google status check is "unknown", not "disconnected"

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cotrainr/pages/profile/settings/integrations_page.dart';
import 'package:cotrainr/repositories/profile_repository.dart';
import 'package:cotrainr/repositories/video_sessions_repository.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/utils/video_session_error_messages.dart';
import 'package:cotrainr/widgets/video_sessions/video_session_people_sheet.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _meetLink = 'https://meet.google.com/abc-defg-hij';

VideoSession _session({
  String status = 'scheduled',
  String? myResponseStatus,
  String? counterpartResponseStatus,
  int participantCount = 1,
  List<VideoSessionPerson> people = const [],
  DateTime? start,
}) {
  return VideoSession(
    id: 'session-1',
    hostId: 'host-1',
    provider: 'google_meet',
    title: 'Strength check-in',
    scheduledStart: start ?? DateTime.now(),
    durationMinutes: 30,
    maxParticipants: 5,
    status: status,
    joinUrl: _meetLink,
    createdAt: DateTime.now(),
    participantCount: participantCount,
    myResponseStatus: myResponseStatus,
    counterpartResponseStatus: counterpartResponseStatus,
    people: people,
  );
}

class _FakeProfileRepo implements ProfileRepository {
  @override
  Future<Map<String, dynamic>?> fetchMyProfile() async =>
      {'role': 'trainer', 'full_name': 'Coach', 'id': 'host-1'};

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Connected on load, but every disconnect attempt fails technically.
class _FailingDisconnectRepo implements VideoSessionsRepository {
  static const rawError =
      'PostgrestException(message: permission denied for table '
      'user_integrations_google, code: 42501)';

  @override
  Future<GoogleMeetIntegrationStatus> getGoogleMeetStatus() async =>
      const GoogleMeetIntegrationStatus(
        connected: true,
        googleEmail: 'coach@example.com',
      );

  @override
  Future<void> disconnectGoogleMeet() async => throw Exception(rawError);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// The status endpoint is unreachable.
class _FailingStatusRepo implements VideoSessionsRepository {
  @override
  Future<GoogleMeetIntegrationStatus> getGoogleMeetStatus() async =>
      throw const SocketException('Failed host lookup: supabase.co');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _integrationsPage(VideoSessionsRepository repo) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => IntegrationsPage(
          profileRepository: _FakeProfileRepo(),
          videoSessionsRepository: repo,
        ),
      ),
    ),
  );
}

String _source(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // Sanitized errors
  // -------------------------------------------------------------------------

  group('sanitized user-facing errors', () {
    test('session load never surfaces Postgrest code or message', () {
      final error = PostgrestException(
        message: 'permission denied for table video_sessions',
        code: '42501',
        details: 'RLS',
        hint: 'check policy',
      );
      final shown = VideoSessionErrorMessages.forLoadSession(error);

      expect(shown, 'Could not load this session. Try again.');
      expect(shown, isNot(contains('42501')));
      expect(shown, isNot(contains('permission denied')));
      expect(shown, isNot(contains('video_sessions')));
      expect(shown.toLowerCase(), isNot(contains('postgrest')));
    });

    test('session detail page renders only sanitized copy', () {
      final src =
          _source('lib/pages/video_sessions/session_detail_page.dart');
      expect(src.contains('VideoSessionErrorMessages'), isTrue);
      expect(src.contains('e.message'), isFalse);
      expect(src.contains('e.code'), isFalse);
      expect(src.contains('e.toString()'), isFalse);
    });

    test('create failure never surfaces a raw FunctionException', () {
      final raw = Exception(
        'FunctionException(status: 500, details: {error: meet_api_failed})',
      );
      final shown = VideoSessionErrorMessages.forCreate(raw);

      expect(shown, 'Could not create the session. Try again.');
      expect(shown, isNot(contains('FunctionException')));
      expect(shown, isNot(contains('500')));
      expect(shown, isNot(contains('meet_api_failed')));
    });

    test('create failure on a dropped connection asks about connectivity', () {
      final shown = VideoSessionErrorMessages.forCreate(
        const SocketException('Failed host lookup: supabase.co'),
      );
      expect(shown, VideoSessionErrorMessages.network);
      expect(shown, isNot(contains('supabase.co')));
    });

    test('schedule page no longer stringifies exceptions', () {
      final src =
          _source('lib/pages/video_sessions/schedule_session_page.dart');
      expect(src.contains("e.toString().replaceFirst('Exception: ', '')"),
          isFalse);
      expect(src.contains('VideoSessionErrorMessages.forCreate'), isTrue);
    });

    testWidgets('disconnect failure shows sanitized copy only',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_integrationsPage(_FailingDisconnectRepo()));
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not disconnect Google Meet. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.textContaining('42501'), findsNothing);
      expect(find.textContaining('user_integrations_google'), findsNothing);
      expect(find.textContaining('permission denied'), findsNothing);
    });

    test('cancel failure copy is sanitized', () {
      final shown = VideoSessionErrorMessages.forCancel(
        PostgrestException(message: 'new row violates RLS', code: '42501'),
      );
      expect(shown, 'Could not cancel the session. Try again.');
      expect(shown, isNot(contains('42501')));
      expect(shown, isNot(contains('RLS')));
    });
  });

  // -------------------------------------------------------------------------
  // OAuth callback slugs
  // -------------------------------------------------------------------------

  group('OAuth callback slugs', () {
    test('internal slugs never reach the user verbatim', () {
      const slugs = [
        'db_save_failed',
        'token_exchange_failed',
        'invalid_state',
        'state_expired',
        'missing_refresh_token',
        'missing_code_or_state',
        'access_denied',
        'something_completely_new',
      ];
      for (final slug in slugs) {
        final shown = VideoSessionErrorMessages.forOAuthSlug(slug);
        expect(shown, isNot(contains('_')), reason: 'slug leaked: $slug');
        expect(shown, isNot(contains(slug)));
        expect(shown.trim(), isNotEmpty);
      }
    });

    test('unknown slugs fall back to the generic connect message', () {
      expect(
        VideoSessionErrorMessages.forOAuthSlug('db_save_failed'),
        VideoSessionErrorMessages.connectGoogle,
      );
      expect(
        VideoSessionErrorMessages.forOAuthSlug('token_exchange_failed'),
        'Google Meet connection failed. Try again.',
      );
    });

    test('cancelled and expired attempts get their own copy', () {
      expect(
        VideoSessionErrorMessages.forOAuthSlug('access_denied'),
        'Google Meet connection was cancelled.',
      );
      expect(
        VideoSessionErrorMessages.forOAuthSlug('state_expired'),
        contains('expired'),
      );
    });

    test('sessions page does not interpolate the raw slug', () {
      final src =
          _source('lib/pages/video_sessions/video_sessions_page_v2.dart');
      expect(src.contains("'Google Meet: \${Uri.decodeComponent(err)}'"),
          isFalse);
      expect(src.contains('VideoSessionErrorMessages.forOAuthSlug'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Group reject semantics
  // -------------------------------------------------------------------------

  group('group reject semantics', () {
    test('1:1 counterpart decline still labels the session Rejected', () {
      final s = _session(
        counterpartResponseStatus: 'rejected',
        participantCount: 1,
      );
      expect(s.isGroupSession, isFalse);
      expect(s.counterpartRejectedOneToOne, isTrue);
      expect(videoSessionMeaningfulStatus(s), 'Rejected');
    });

    test('one decline in a group does not label the whole session', () {
      final s = _session(
        counterpartResponseStatus: 'rejected',
        participantCount: 3,
      );
      expect(s.isGroupSession, isTrue);
      expect(s.counterpartRejected, isTrue);
      expect(s.counterpartRejectedOneToOne, isFalse);
      expect(videoSessionMeaningfulStatus(s), isNull);
      expect(s.isUpcoming, isTrue);
    });

    test('my own decline is still shown to me in a group', () {
      final s = _session(myResponseStatus: 'rejected', participantCount: 3);
      expect(videoSessionMeaningfulStatus(s), 'Rejected');
    });

    test('group summary counts only responses the server reported', () {
      final s = _session(
        participantCount: 3,
        people: const [
          VideoSessionPerson(
            userId: 'host-1',
            displayName: 'Coach',
            role: 'host',
          ),
          VideoSessionPerson(
            userId: 'u1',
            displayName: 'Asha',
            responseStatus: 'accepted',
          ),
          VideoSessionPerson(
            userId: 'u2',
            displayName: 'Ben',
            responseStatus: 'accepted',
          ),
          VideoSessionPerson(
            userId: 'u3',
            displayName: 'Cara',
            responseStatus: 'rejected',
          ),
        ],
      );
      expect(s.participantResponseSummary, '2 accepted · 1 declined');
    });

    test('group summary invents no count when responses are unknown', () {
      final s = _session(
        participantCount: 3,
        counterpartResponseStatus: 'rejected',
      );
      expect(s.participantResponseSummary, 'Someone declined');
      expect(s.participantResponseSummary, isNot(contains('1 declined')));
    });

    test('1:1 sessions get no group summary', () {
      final s = _session(
        participantCount: 1,
        counterpartResponseStatus: 'rejected',
      );
      expect(s.participantResponseSummary, isNull);
    });

    test('one decline never disables Join for anyone else', () {
      final s = _session(
        participantCount: 3,
        counterpartResponseStatus: 'rejected',
        start: DateTime.now(),
      );
      expect(s.canJoin, isTrue);

      final mine = _session(
        participantCount: 3,
        myResponseStatus: 'rejected',
        start: DateTime.now(),
      );
      expect(mine.canJoin, isFalse,
          reason: 'my own decline still hides Join for me');
    });

    test('detail page no longer keys the global banner off any decline', () {
      final src =
          _source('lib/pages/video_sessions/session_detail_page.dart');
      expect(src.contains('session.counterpartRejectedOneToOne'), isTrue);
      expect(
        src.contains('} else if (session.counterpartRejected) ...['),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Per-participant response state
  // -------------------------------------------------------------------------

  group('per-participant response state', () {
    test('server-reported state is used as-is', () {
      final person = const VideoSessionPerson(
        userId: 'u3',
        displayName: 'Cara',
        responseStatus: 'rejected',
      );
      final s = _session(participantCount: 3, people: [person]);
      expect(s.responseStatusFor(person, myUserId: 'host-1'), 'rejected');
    });

    test('my own row falls back to my authoritative response', () {
      final me = const VideoSessionPerson(userId: 'me', displayName: 'Me');
      final s = _session(
        participantCount: 3,
        myResponseStatus: 'rejected',
        people: [me],
      );
      expect(s.responseStatusFor(me, myUserId: 'me'), 'rejected');
    });

    test('unknown group responses render nothing rather than guessing', () {
      final other = const VideoSessionPerson(userId: 'u9', displayName: 'Dee');
      final s = _session(
        participantCount: 3,
        counterpartResponseStatus: 'rejected',
        people: [other],
      );
      expect(s.responseStatusFor(other, myUserId: 'me'), isNull);
    });

    test('1:1 counterpart row uses the counterpart response', () {
      final other = const VideoSessionPerson(userId: 'u9', displayName: 'Dee');
      final s = _session(
        participantCount: 1,
        counterpartResponseStatus: 'rejected',
        people: [other],
      );
      expect(s.responseStatusFor(other, myUserId: 'me'), 'rejected');
    });

    testWidgets('response chip shows decisions and hides pending',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                VideoSessionResponseChip(responseStatus: 'rejected'),
                VideoSessionResponseChip(responseStatus: 'accepted'),
                VideoSessionResponseChip(responseStatus: 'pending'),
                VideoSessionResponseChip(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Google status is never guessed
  // -------------------------------------------------------------------------

  group('Google Meet status', () {
    test('a failed check is unknown, not disconnected', () {
      final unknown = GoogleMeetIntegrationStatus.unknown();
      expect(unknown.isUnknown, isTrue);
      expect(unknown.confirmedNotConnected, isFalse);

      final disconnected = GoogleMeetIntegrationStatus.disconnected();
      expect(disconnected.isUnknown, isFalse);
      expect(disconnected.confirmedNotConnected, isTrue);
    });

    test('a failed check keeps a previously confirmed connection', () {
      const lastKnown = GoogleMeetIntegrationStatus(
        connected: true,
        googleEmail: 'coach@example.com',
      );
      final unknown =
          GoogleMeetIntegrationStatus.unknown(lastKnown: lastKnown);

      expect(unknown.connected, isTrue);
      expect(unknown.googleEmail, 'coach@example.com');
      expect(unknown.isUnknown, isTrue);
    });

    test('the loading phase is not a disconnected account', () {
      final loading = GoogleMeetIntegrationStatus.loading();
      expect(loading.isLoading, isTrue);
      expect(loading.confirmedNotConnected, isFalse);
    });

    test('the repository reports failure instead of returning disconnected',
        () {
      final src = _source('lib/repositories/video_sessions_repository.dart');
      final body = src.substring(src.indexOf('getGoogleMeetStatus'));
      final method = body.substring(0, body.indexOf('Future<String> getGoogleOAuthUrl'));
      expect(method.contains('GoogleMeetIntegrationStatus.disconnected()'),
          isFalse);
      expect(method.contains('throw VideoSessionCreateException'), isTrue);
    });

    testWidgets('a failed status check does not say "Not connected"',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_integrationsPage(_FailingStatusRepo()));
      await tester.pumpAndSettle();

      expect(find.text('Not connected'), findsNothing);
      expect(find.text('Connect Google Meet'), findsNothing);
      expect(find.text('Status unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('Failed host lookup'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Cancel result
  // -------------------------------------------------------------------------

  group('cancelSession result', () {
    // A no-row update (RLS denial or wrong id) returns success from PostgREST,
    // so the repository must inspect the affected rows. That path needs a live
    // PostgREST response to exercise end to end; the contract is asserted here
    // and verified on device via the deployment checklist.
    test('the update is verified instead of assumed', () {
      final src = _source('lib/repositories/video_sessions_repository.dart');
      final start = src.indexOf('Future<void> cancelSession');
      expect(start, greaterThan(-1));
      final method = src.substring(start, src.indexOf('}', src.indexOf('CANCEL_NOT_APPLIED')));

      expect(method.contains(".select('id')"), isTrue);
      expect(method.contains('rows is! List || rows.isEmpty'), isTrue);
      expect(method.contains('CANCEL_NOT_APPLIED'), isTrue);
      // The authorization model is unchanged: still id + host_id, RLS enforced.
      expect(method.contains(".eq('id', sessionId)"), isTrue);
      expect(method.contains(".eq('host_id', me)"), isTrue);
    });

    test('a failed cancel cannot report success in the UI', () {
      final src =
          _source('lib/pages/video_sessions/session_detail_page.dart');
      final start = src.indexOf('Future<void> _cancel()');
      final method = src.substring(start, src.indexOf('Future<void> _edit()'));

      // Success copy sits before the catch, so a throw skips it.
      expect(
        method.indexOf("showHubSnackBar(context, 'Session cancelled')"),
        lessThan(method.indexOf('catch (e, s)')),
      );
      expect(method.contains('VideoSessionErrorMessages.forCancel'), isTrue);
    });
  });
}
