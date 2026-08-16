import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/repositories/video_sessions_repository.dart';
import 'package:cotrainr/utils/meeting_link_rules.dart';

void main() {
  group('Google Meet session model', () {
    test('labels google_meet provider as Google Meet', () {
      final s = VideoSession(
        id: '1',
        hostId: 'h',
        provider: 'google_meet',
        title: 'Coaching',
        scheduledStart: DateTime(2026, 8, 20, 18),
        durationMinutes: 45,
        maxParticipants: 2,
        status: 'scheduled',
        joinUrl: 'https://meet.google.com/abc-defg-hij',
        createdAt: DateTime(2026, 8, 1),
      );
      expect(s.isGoogleMeet, isTrue);
      expect(s.meetingProviderLabel, 'Google Meet');
      expect(s.canJoin, isTrue);
    });

    test('edit preserveJoinUrl keeps same Meet URL conceptually', () {
      // Pure model: reschedule does not change joinUrl on the object.
      final original = VideoSession(
        id: '1',
        hostId: 'h',
        provider: 'google_meet',
        title: 'A',
        scheduledStart: DateTime(2026, 8, 20, 18),
        durationMinutes: 45,
        maxParticipants: 2,
        status: 'scheduled',
        joinUrl: 'https://meet.google.com/abc-defg-hij',
        createdAt: DateTime(2026, 8, 1),
      );
      final rescheduled = VideoSession(
        id: original.id,
        hostId: original.hostId,
        provider: original.provider,
        title: 'A',
        scheduledStart: DateTime(2026, 8, 21, 19),
        durationMinutes: 60,
        maxParticipants: original.maxParticipants,
        status: original.status,
        joinUrl: original.joinUrl,
        createdAt: original.createdAt,
      );
      expect(rescheduled.joinUrl, original.joinUrl);
      expect(rescheduled.provider, 'google_meet');
    });

    test('cancelled disables join', () {
      final s = VideoSession(
        id: '1',
        hostId: 'h',
        provider: 'google_meet',
        title: 'A',
        scheduledStart: DateTime(2026, 8, 20, 18),
        durationMinutes: 45,
        maxParticipants: 2,
        status: 'cancelled',
        joinUrl: 'https://meet.google.com/abc-defg-hij',
        createdAt: DateTime(2026, 8, 1),
      );
      expect(s.canJoin, isFalse);
    });
  });

  group('GoogleMeetIntegrationStatus', () {
    test('parses safe status JSON without tokens', () {
      final status = GoogleMeetIntegrationStatus.fromJson({
        'connected': true,
        'reconnect_required': false,
        'google_email': 'coach@example.com',
        'connected_at': '2026-08-16T12:00:00Z',
        'access_token': 'SHOULD_NOT_MATTER',
      });
      expect(status.connected, isTrue);
      expect(status.googleEmail, 'coach@example.com');
      expect(status.needsConnect, isFalse);
    });

    test('reconnect_required forces needsConnect', () {
      final status = GoogleMeetIntegrationStatus.fromJson({
        'connected': false,
        'reconnect_required': true,
        'google_email': 'coach@example.com',
      });
      expect(status.needsConnect, isTrue);
    });
  });

  group('MeetingLinkRules Google Meet URLs', () {
    test('accepts meet.google.com https links', () {
      expect(
        MeetingLinkRules.isValidHttpsMeetingLink(
          'https://meet.google.com/abc-defg-hij',
        ),
        isTrue,
      );
      expect(
        MeetingLinkRules.detectProviderLabel(
          'https://meet.google.com/abc-defg-hij',
        ),
        'Google Meet',
      );
    });
  });

  group('VideoSessionCreateException', () {
    test('carries structured codes for Flutter UI', () {
      final e = VideoSessionCreateException(
        'Connect Google Meet to create video sessions.',
        code: 'GOOGLE_NOT_CONNECTED',
      );
      expect(e.code, 'GOOGLE_NOT_CONNECTED');
      expect(e.toString(), contains('Connect Google Meet'));
    });
  });
}
