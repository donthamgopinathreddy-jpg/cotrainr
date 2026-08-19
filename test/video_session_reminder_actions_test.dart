import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/repositories/notifications_repository.dart';
import 'package:cotrainr/repositories/video_sessions_repository.dart';
import 'package:cotrainr/services/video_session_notification_actions.dart';
import 'package:cotrainr/services/video_session_pending_navigation.dart';
import 'package:cotrainr/video_sessions/video_session_notification_logic.dart';
import 'package:cotrainr/widgets/video_sessions/video_session_reject_sheet.dart';

VideoSession _session({
  String status = 'scheduled',
  String? myResponseStatus,
  String? myResponseReason,
  String? counterpartResponseStatus,
  String? counterpartResponseReason,
  DateTime? start,
}) {
  return VideoSession(
    id: '11111111-1111-1111-1111-111111111111',
    hostId: 'host-1',
    provider: 'google_meet',
    title: 'Nutrition Check-in',
    scheduledStart: start ?? DateTime(2026, 8, 18, 19, 30),
    durationMinutes: 30,
    maxParticipants: 2,
    status: status,
    joinUrl: 'https://meet.google.com/abc-defg-hij',
    createdAt: DateTime(2026, 8, 1),
    counterpartyName: 'Rahul Sharma',
    participantNames: const ['Rahul Sharma'],
    participantCount: 1,
    myResponseStatus: myResponseStatus,
    myResponseReason: myResponseReason,
    counterpartResponseStatus: counterpartResponseStatus,
    counterpartResponseReason: counterpartResponseReason,
  );
}

void main() {
  group('reminder generation', () {
    final start = DateTime(2026, 8, 20, 18, 0);

    test('5-minute reminder is generated in the window', () {
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

    test('start-time reminder is generated at session start', () {
      expect(
        VideoSessionNotificationLogic.shouldDispatchReminder(
          status: 'scheduled',
          kind: 'starting',
          scheduledStart: start,
          durationMinutes: 30,
          now: start,
        ),
        isTrue,
      );
    });

    test('duplicate dispatcher uses the same idempotency key', () {
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
      expect(
        VideoSessionNotificationLogic.idempotencyKey(
          sessionId: 's1',
          userId: 'u1',
          kind: 'starting',
        ),
        isNot(first),
      );
    });

    test('cancelled session receives no reminder', () {
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
    });

    test('rejected participant receives no start reminder', () {
      expect(
        VideoSessionNotificationLogic.shouldDispatchReminder(
          status: 'scheduled',
          kind: 'starting',
          scheduledStart: start,
          durationMinutes: 30,
          now: start,
          participantRejected: true,
        ),
        isFalse,
      );
    });
  });

  group('JOIN / REJECT payload and routing', () {
    const sessionId = '11111111-1111-1111-1111-111111111111';

    test('JOIN payload contains video_session_id', () {
      final payload = VideoSessionNotificationLogic.reminderPayload(
        type: VideoSessionNotificationLogic.reminder5mType,
        sessionId: sessionId,
        hostId: 'host-1',
        counterpartName: 'Rahul Sharma',
        scheduledStart: DateTime.utc(2026, 8, 18, 17, 44),
        joinUrl: 'https://meet.google.com/abc-defg-hij',
      );
      expect(payload['video_session_id'], sessionId);
      expect(payload['type'], 'video_session_reminder_5m');
      expect(payload['actions'], ['join', 'reject']);
      expect(payload['counterpart_name'], 'Rahul Sharma');

      final encoded = VideoSessionNotificationActions.encodePayload(
        action: 'join',
        sessionId: sessionId,
        joinUrl: payload['join_url'] as String,
        type: payload['type'] as String,
      );
      final decoded = VideoSessionNotificationActions.decodePayload(encoded)!;
      expect(decoded['video_session_id'], sessionId);
      expect(
        VideoSessionNotificationActions.sessionIdFrom(decoded),
        sessionId,
      );
    });

    test('REJECT opens session reason flow via query action', () {
      expect(
        VideoSessionPendingNavigation.routeFor(
          sessionId: sessionId,
          action: 'reject',
        ),
        '/video/session/$sessionId?action=reject',
      );
      expect(
        VideoSessionPendingNavigation.routeFor(
          sessionId: sessionId,
          action: 'join',
        ),
        '/video/session/$sessionId?action=join',
      );
    });

    test('cold-start action routing keeps session id', () {
      expect(
        VideoSessionPendingNavigation.isSessionActionRoute(
          '/video/session/$sessionId?action=reject',
        ),
        isTrue,
      );
      expect(
        VideoSessionPendingNavigation.isSessionActionRoute(
          '/video/google-connected',
        ),
        isFalse,
      );
      expect(
        VideoSessionPendingNavigation.isSessionActionRoute('/video'),
        isFalse,
      );
    });
  });

  group('rejection model', () {
    test('persisted reason + timestamp live on the session object', () {
      final at = DateTime.utc(2026, 8, 18, 17, 40);
      final s = _session(
        myResponseStatus: 'rejected',
        myResponseReason: 'Need to reschedule',
      ).copyWith(myRespondedAt: at);
      expect(s.hasRejected, isTrue);
      expect(s.myResponseReason, 'Need to reschedule');
      expect(s.myRespondedAt, at);
      expect(s.canJoin, isFalse);
    });

    test('rejection does not cancel the session', () {
      final s = _session(myResponseStatus: 'rejected');
      expect(s.isCancelled, isFalse);
      expect(s.status, 'scheduled');
    });

    test('other participant receives rejection notification copy', () {
      expect(
        VideoSessionNotificationLogic.rejectedTitle('Gopinath'),
        "Gopinath can't attend",
      );
      expect(
        VideoSessionNotificationLogic.rejectedBody('Need to reschedule'),
        'Reason: Need to reschedule',
      );
      expect(
        NotificationsRepository.isVideoSessionType('video_session_rejected'),
        isTrue,
      );
      expect(
        NotificationsRepository.videoSessionNotificationTypes,
        contains('video_session_rejected'),
      );
    });

    test('user cannot reject a session they do not belong to', () {
      expect(
        VideoSessionNotificationLogic.canRespond(
          actorId: 'intruder',
          memberIds: const ['host-1', 'client-1'],
        ),
        isFalse,
      );
      expect(
        VideoSessionNotificationLogic.canRespond(
          actorId: 'client-1',
          memberIds: const ['host-1', 'client-1'],
        ),
        isTrue,
      );
    });

    test('actual counterpart name is used in reminder copy', () {
      expect(
        VideoSessionNotificationLogic.reminderBody(
          counterpartName: 'Rahul Sharma',
          whenLabel: '6:44 PM',
        ),
        'Your session with Rahul Sharma starts at 6:44 PM.',
      );
      expect(
        VideoSessionNotificationLogic.startingBody(
          counterpartName: 'Rahul Sharma',
        ).contains('session partner'),
        isFalse,
      );
    });

    test('session-created notifications still use created type', () {
      final payload = VideoSessionNotificationLogic.createdPayload(
        sessionId: '11111111-1111-1111-1111-111111111111',
        hostId: 'host-1',
        counterpartName: 'Rahul Sharma',
        scheduledStart: DateTime.utc(2026, 8, 18, 17, 44),
      );
      expect(payload['type'], 'video_session_created');
      expect(
        VideoSessionNotificationLogic.isActionableReminderType(payload['type'] as String),
        isFalse,
      );
    });
  });

  group('red-dot types', () {
    test('unread types still include created, reminders, and rejected', () {
      expect(
        NotificationsRepository.videoSessionNotificationTypes,
        containsAll([
          'video_session_created',
          'video_session_reminder_5m',
          'video_session_starting',
          'video_session_rejected',
        ]),
      );
    });
  });

  group('reject sheet', () {
    testWidgets('REJECT flow shows reason picker', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => showVideoSessionRejectSheet(
                    context: context,
                    counterpartDisplayName: 'Rahul Sharma',
                  ),
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text("Can't attend?"), findsOneWidget);
      expect(find.text('Let Rahul Sharma know why.'), findsOneWidget);
      expect(find.text('Need to reschedule'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });
  });
}
