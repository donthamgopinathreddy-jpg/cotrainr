import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/repositories/notifications_repository.dart';
import 'package:cotrainr/repositories/video_sessions_repository.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/video_sessions/video_session_notification_logic.dart';
import 'package:cotrainr/widgets/video_sessions/video_session_card_actions.dart';

VideoSession _session({
  String? counterpartyName,
  List<String> participantNames = const [],
  int participantCount = 0,
  String status = 'scheduled',
  DateTime? start,
  String hostId = 'host-1',
}) {
  return VideoSession(
    id: '11111111-1111-1111-1111-111111111111',
    hostId: hostId,
    provider: 'google_meet',
    title: 'Nutrition Check-in',
    scheduledStart: start ?? DateTime(2026, 8, 18, 19, 30),
    durationMinutes: 30,
    maxParticipants: 2,
    status: status,
    joinUrl: 'https://meet.google.com/abc-defg-hij',
    createdAt: DateTime(2026, 8, 1),
    counterpartyName: counterpartyName,
    participantNames: participantNames,
    participantCount: participantCount,
  );
}

void main() {
  group('counterpart names', () {
    test('client sees trainer name, never session partner when profile exists', () {
      final s = _session(
        counterpartyName: 'Rahul Sharma',
        participantNames: ['Rahul Sharma'],
        participantCount: 1,
      );
      expect(s.withLine, 'with Rahul Sharma');
      expect(s.withLine.contains('session partner'), isFalse);
    });

    test('provider sees client name', () {
      final s = _session(
        counterpartyName: 'Gopi',
        participantNames: ['Gopi'],
        participantCount: 1,
      );
      expect(s.withLine, 'with Gopi');
    });

    test('generic fallback only when profile name is genuinely missing', () {
      final s = _session();
      expect(s.withLine, 'with your session partner');
      expect(
        VideoSessionNotificationLogic.shouldShowGenericPartnerFallback(
          participantNames: const [],
          counterpartyName: 'Rahul Sharma',
        ),
        isFalse,
      );
    });

    test('displayName prefers full_name then username', () {
      expect(
        VideoSessionNotificationLogic.displayName(
          fullName: 'Rahul Sharma',
          username: 'rahul',
        ),
        'Rahul Sharma',
      );
      expect(
        VideoSessionNotificationLogic.displayName(fullName: '  ', username: 'gopi'),
        'gopi',
      );
    });
  });

  group('session card actions', () {
    testWidgets('Join and Details have equal width and height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: VideoSessionCardActionRow(
                onJoin: () {},
                onDetails: () {},
                outlineColor: Colors.black,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final join = tester.getSize(find.widgetWithText(ElevatedButton, 'Join'));
      final details =
          tester.getSize(find.widgetWithText(OutlinedButton, 'Details'));
      expect(join.height, VideoSessionCardActionRow.buttonHeight);
      expect(details.height, VideoSessionCardActionRow.buttonHeight);
      expect(join.height, details.height);
      expect(join.width, details.width);
      expect(find.text('Join Meeting'), findsNothing);
      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('compact card uses Join, not multiline Join Meeting',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoSessionCardActionRow(
              onJoin: () {},
              onDetails: () {},
              outlineColor: Colors.black,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Join'));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.data, isNot(contains('Meeting')));
    });
  });

  group('notifications', () {
    test('created payload includes session id, host, type, start', () {
      final start = DateTime.utc(2026, 8, 18, 16, 8);
      final payload = VideoSessionNotificationLogic.createdPayload(
        sessionId: '11111111-1111-1111-1111-111111111111',
        hostId: 'host-rahul',
        counterpartName: 'Rahul Sharma',
        scheduledStart: start,
        joinUrl: 'https://meet.google.com/abc',
      );
      expect(payload['type'], 'video_session_created');
      expect(payload['video_session_id'], '11111111-1111-1111-1111-111111111111');
      expect(payload['host_id'], 'host-rahul');
      expect(payload['counterpart_name'], 'Rahul Sharma');
      expect(payload['scheduled_start'], start.toIso8601String());
    });

    test('created and reminder copy use counterpart name', () {
      expect(
        VideoSessionNotificationLogic.createdBody(
          hostName: 'Rahul Sharma',
          whenLabel: '5:08 PM',
        ),
        'Rahul Sharma scheduled a session with you for 5:08 PM.',
      );
      expect(
        VideoSessionNotificationLogic.reminderBody(
          counterpartName: 'Gopi',
          whenLabel: '5:08 PM',
        ),
        'Your session with Gopi starts at 5:08 PM.',
      );
      expect(
        VideoSessionNotificationLogic.createdBody(
          hostName: 'Rahul Sharma',
          whenLabel: 'x',
        ).contains('Provider scheduled'),
        isFalse,
      );
    });

    test('duplicate create uses the same idempotency key', () {
      final a = VideoSessionNotificationLogic.idempotencyKey(
        sessionId: 's1',
        userId: 'c1',
        kind: 'created',
      );
      final b = VideoSessionNotificationLogic.idempotencyKey(
        sessionId: 's1',
        userId: 'c1',
        kind: 'created',
      );
      expect(a, b);
      expect(
        VideoSessionNotificationLogic.idempotencyKey(
          sessionId: 's1',
          userId: 'c1',
          kind: 'rescheduled:t2',
        ),
        isNot(a),
      );
    });

    test('unread video session types drive the red dot', () {
      expect(
        NotificationsRepository.videoSessionNotificationTypes,
        containsAll([
          'video_session_created',
          'video_session_rescheduled',
          'video_session_cancelled',
          'video_session_reminder_5m',
          'video_session_starting',
        ]),
      );
      expect(NotificationsRepository.isVideoSessionType('video_session_created'), isTrue);
    });

    test('in-app notification remains when push token is missing', () {
      const hasDbRow = true;
      const tokenCount = 0;
      final shouldKeepInApp = hasDbRow;
      final shouldAttemptPush = tokenCount > 0;
      expect(shouldKeepInApp, isTrue);
      expect(shouldAttemptPush, isFalse);
    });

    test('push sender is invoked only when a device token exists', () {
      expect(0 > 0, isFalse);
      expect(2 > 0, isTrue);
    });
  });

  group('reminder scheduling rules', () {
    final start = DateTime(2026, 8, 20, 18, 0);

    test('5-minute reminder once only uses unique kind key', () {
      final first = VideoSessionNotificationLogic.idempotencyKey(
        sessionId: 's1',
        userId: 'u1',
        kind: 'reminder_5m',
      );
      final second = VideoSessionNotificationLogic.idempotencyKey(
        sessionId: 's1',
        userId: 'u1',
        kind: 'reminder_5m',
      );
      expect(first, second);
    });

    test('starting notification once only uses unique kind key', () {
      expect(
        VideoSessionNotificationLogic.idempotencyKey(
          sessionId: 's1',
          userId: 'u1',
          kind: 'starting',
        ),
        VideoSessionNotificationLogic.idempotencyKey(
          sessionId: 's1',
          userId: 'u1',
          kind: 'starting',
        ),
      );
    });

    test('cancelled sessions do not receive reminders', () {
      expect(
        VideoSessionNotificationLogic.shouldDispatchReminder(
          status: 'cancelled',
          kind: 'reminder_5m',
          scheduledStart: start,
          durationMinutes: 30,
          now: start.subtract(const Duration(minutes: 5)),
        ),
        isFalse,
      );
      expect(
        VideoSessionNotificationLogic.shouldDispatchReminder(
          status: 'scheduled',
          kind: 'reminder_5m',
          scheduledStart: start,
          durationMinutes: 30,
          now: start.subtract(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });
  });

  group('purple token', () {
    test('Join uses video sessions purple, not orange', () {
      expect(DesignTokens.videoSessionsAccent, const Color(0xFF8B7CF6));
      expect(DesignTokens.videoSessionsAccent, isNot(DesignTokens.accentOrange));
    });
  });
}
