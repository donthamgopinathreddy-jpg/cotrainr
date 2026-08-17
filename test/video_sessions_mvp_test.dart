import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/utils/meeting_link_rules.dart';

void main() {
  group('MeetingLinkRules', () {
    test('requires https', () {
      expect(
        MeetingLinkRules.validateHttpsMeetingLink('http://meet.google.com/abc'),
        isNotNull,
      );
      expect(
        MeetingLinkRules.validateHttpsMeetingLink('https://meet.google.com/abc'),
        isNull,
      );
      expect(MeetingLinkRules.validateHttpsMeetingLink(''), isNotNull);
      expect(MeetingLinkRules.validateHttpsMeetingLink('not-a-url'), isNotNull);
    });

    test('detects common providers', () {
      expect(
        MeetingLinkRules.detectProviderLabel('https://meet.google.com/abc-def'),
        'Google Meet',
      );
      expect(
        MeetingLinkRules.detectProviderLabel('https://us05web.zoom.us/j/123'),
        'Zoom',
      );
      expect(
        MeetingLinkRules.detectProviderLabel('https://teams.microsoft.com/l/meetup'),
        'Microsoft Teams',
      );
    });
  });

  group('VideoSessionJoinRules', () {
    final start = DateTime(2026, 8, 20, 18, 0);

    test('cancelled never joinable', () {
      final e = VideoSessionJoinRules.evaluate(
        status: 'cancelled',
        scheduledStart: start,
        durationMinutes: 45,
        joinUrl: 'https://meet.google.com/x',
        now: start,
      );
      expect(e, VideoSessionJoinEligibility.cancelled);
      expect(VideoSessionJoinRules.canJoin(e), isFalse);
    });

    test('invalid link not joinable', () {
      final e = VideoSessionJoinRules.evaluate(
        status: 'scheduled',
        scheduledStart: start,
        durationMinutes: 45,
        joinUrl: 'http://insecure.example',
        now: start,
      );
      expect(e, VideoSessionJoinEligibility.invalidLink);
    });

    test('past session not joinable', () {
      final e = VideoSessionJoinRules.evaluate(
        status: 'scheduled',
        scheduledStart: start,
        durationMinutes: 45,
        joinUrl: 'https://meet.google.com/x',
        now: start.add(const Duration(hours: 3)),
      );
      expect(e, VideoSessionJoinEligibility.past);
    });

    test('upcoming more than 5 minutes before start is too early', () {
      final e = VideoSessionJoinRules.evaluate(
        status: 'scheduled',
        scheduledStart: start,
        durationMinutes: 45,
        joinUrl: 'https://meet.google.com/x',
        now: start.subtract(const Duration(hours: 2)),
      );
      expect(e, VideoSessionJoinEligibility.tooEarly);
      expect(VideoSessionJoinRules.canJoin(e), isFalse);
    });
  });
}
