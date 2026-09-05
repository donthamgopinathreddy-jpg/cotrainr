import 'dart:io';

import 'package:cotrainr/models/community_event.dart';
import 'package:cotrainr/providers/community_events_provider.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/utils/community_event_datetime.dart';
import 'package:cotrainr/utils/event_registration_validation.dart';
import 'package:cotrainr/widgets/home_v3/home_community_event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

CommunityEvent _event({
  String id = 'evt-1',
  String title = 'Sunrise Park Run',
  DateTime? startsAt,
  DateTime? endsAt,
  String? shortDescription,
  String? locationName = 'Central Park',
  String? mapUrl,
  bool registrationEnabled = true,
  DateTime? registrationDeadline,
  int? maxParticipants,
}) {
  final start = startsAt ?? DateTime(2026, 9, 20, 9, 0);
  return CommunityEvent(
    id: id,
    title: title,
    shortDescription: shortDescription,
    fullDescription: 'Full details about the run.',
    startsAt: start,
    endsAt: endsAt ?? start.add(const Duration(hours: 2)),
    locationName: locationName,
    mapUrl: mapUrl,
    registrationEnabled: registrationEnabled,
    registrationDeadline: registrationDeadline,
    maxParticipants: maxParticipants,
  );
}

CommunityEventCardData _card({
  CommunityEvent? event,
  int attendeeCount = 12,
  bool isRegistered = false,
}) {
  return CommunityEventCardData(
    event: event ?? _event(),
    attendeeCount: attendeeCount,
    isRegistered: isRegistered,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('CommunityEventDateTime', () {
    test('Today / Tomorrow / Happening now / weekday', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Prefer a later-today start; if near midnight, use earlier today + "Happening now" path separately.
      final laterToday = today.add(const Duration(hours: 22));
      final todayEvent = _event(
        startsAt: laterToday.isAfter(now)
            ? laterToday
            : today.add(const Duration(hours: 1)),
      );
      final todayLabel =
          CommunityEventDateTime.scheduleLabel(todayEvent, now: now);
      if (todayEvent.isHappeningNow) {
        expect(todayLabel, 'Happening now');
      } else {
        expect(todayLabel.startsWith('Today • '), isTrue);
      }

      final tomorrowStart = today.add(const Duration(days: 1, hours: 9));
      expect(
        CommunityEventDateTime.scheduleLabel(
          _event(startsAt: tomorrowStart),
          now: now,
        ),
        startsWith('Tomorrow • '),
      );

      final happening = _event(
        startsAt: now.subtract(const Duration(minutes: 20)),
        endsAt: now.add(const Duration(hours: 1)),
      );
      expect(CommunityEventDateTime.scheduleLabel(happening), 'Happening now');

      final weekdayStart = today.add(const Duration(days: 10, hours: 9));
      final weekdayLabel = CommunityEventDateTime.scheduleLabel(
        _event(startsAt: weekdayStart),
        now: now,
      );
      expect(weekdayLabel.contains('•'), isTrue);
      expect(weekdayLabel.startsWith('Today'), isFalse);
      expect(weekdayLabel.startsWith('Tomorrow'), isFalse);
      expect(weekdayLabel.startsWith('Happening'), isFalse);

      final badge = CommunityEventDateTime.dateBadge(DateTime(2026, 9, 20));
      expect(badge.$1, 'SEP');
      expect(badge.$2, '20');
    });
  });

  group('EventJoinAvailability', () {
    final now = DateTime(2026, 9, 5, 12, 0);

    test('canJoin', () {
      final card = _card(
        event: _event(startsAt: DateTime(2026, 9, 20, 9, 0)),
      );
      expect(card.joinAvailability(now: now), EventJoinAvailability.canJoin);
    });

    test('joined', () {
      final card = _card(isRegistered: true);
      expect(card.joinAvailability(now: now), EventJoinAvailability.joined);
    });

    test('full', () {
      final card = _card(
        attendeeCount: 10,
        event: _event(maxParticipants: 10),
      );
      expect(card.joinAvailability(now: now), EventJoinAvailability.full);
    });

    test('deadline', () {
      final card = _card(
        event: _event(
          registrationDeadline: DateTime(2026, 9, 4, 12, 0),
        ),
      );
      expect(
        card.joinAvailability(now: now),
        EventJoinAvailability.deadlinePassed,
      );
    });

    test('disabled', () {
      final card = _card(
        event: _event(registrationEnabled: false),
      );
      expect(card.joinAvailability(now: now), EventJoinAvailability.disabled);
    });

    test('ended', () {
      final card = _card(
        event: _event(
          startsAt: DateTime(2026, 9, 1, 9, 0),
          endsAt: DateTime(2026, 9, 1, 11, 0),
        ),
      );
      expect(card.joinAvailability(now: now), EventJoinAvailability.ended);
    });
  });

  group('EventRegistrationValidation', () {
    test('name / phone / email', () {
      expect(EventRegistrationValidation.nameError(null), isNotNull);
      expect(EventRegistrationValidation.nameError(''), isNotNull);
      expect(EventRegistrationValidation.nameError('Ada'), isNull);

      expect(EventRegistrationValidation.phoneError(null), isNotNull);
      expect(EventRegistrationValidation.phoneError('123'), isNotNull);
      expect(EventRegistrationValidation.phoneError('+919876543210'), isNull);

      expect(EventRegistrationValidation.emailError(null), isNotNull);
      expect(EventRegistrationValidation.emailError('bad'), isNotNull);
      expect(EventRegistrationValidation.emailError('a@b.co'), isNull);

      expect(
        EventRegistrationValidation.sanitizedRegistrationError('full'),
        'This event is full.',
      );
    });
  });

  group('CommunityEventCardData.fromJson', () {
    test('parses nested event payload', () {
      final data = CommunityEventCardData.fromJson({
        'attendee_count': 7,
        'is_registered': true,
        'event': {
          'id': 'e1',
          'title': 'Yoga in the Park',
          'short_description': 'Gentle flow',
          'full_description': 'Bring a mat',
          'starts_at': '2026-09-20T09:00:00.000Z',
          'ends_at': '2026-09-20T10:30:00.000Z',
          'location_name': 'Lake View',
          'map_url': 'https://maps.google.com/?q=lake',
          'image_path': null,
          'registration_enabled': true,
          'registration_deadline': null,
          'max_participants': 40,
          'is_published': true,
        },
      });

      expect(data.event.id, 'e1');
      expect(data.event.title, 'Yoga in the Park');
      expect(data.attendeeCount, 7);
      expect(data.isRegistered, isTrue);
      expect(data.event.hasValidMapUrl, isTrue);
    });
  });

  group('hasValidMapUrl', () {
    test('accepts http(s) with host and rejects junk', () {
      expect(
        _event(mapUrl: 'https://maps.google.com/?q=x').hasValidMapUrl,
        isTrue,
      );
      expect(_event(mapUrl: 'http://example.com').hasValidMapUrl, isTrue);
      expect(_event(mapUrl: 'ftp://example.com').hasValidMapUrl, isFalse);
      expect(_event(mapUrl: 'not-a-url').hasValidMapUrl, isFalse);
      expect(_event(mapUrl: null).hasValidMapUrl, isFalse);
      expect(_event(mapUrl: '').hasValidMapUrl, isFalse);
    });
  });

  group('source contracts — home wiring', () {
    test('three homes place HomeCommunityEventCard after HeroHeaderV3', () {
      for (final path in [
        'lib/pages/home/home_page_v3.dart',
        'lib/pages/trainer/trainer_home_page.dart',
        'lib/pages/nutritionist/nutritionist_home_page.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('HomeCommunityEventCard'), isTrue, reason: path);
        expect(src.contains('HeroHeaderV3'), isTrue, reason: path);
        expect(src.contains('homeCommunityEventProvider'), isTrue, reason: path);

        final heroIdx = src.indexOf('HeroHeaderV3');
        final eventIdx = src.indexOf('HomeCommunityEventCard');
        final metricsIdx = src.indexOf('UnifiedMetricsTileV3');
        expect(heroIdx, greaterThanOrEqualTo(0), reason: path);
        expect(eventIdx, greaterThan(heroIdx), reason: path);
        expect(metricsIdx, greaterThan(eventIdx), reason: path);
      }
    });

    test('Join uses separate handler from card navigation', () {
      final src = File('lib/widgets/home_v3/home_community_event_card.dart')
          .readAsStringSync();
      expect(src.contains('_openJoin'), isTrue);
      expect(src.contains('_openDetails'), isTrue);
      expect(src.contains('onJoin: () => _openJoin(context)'), isTrue);
      expect(src.contains("context.push('/events/"), isTrue);
    });
  });

  group('HomeCommunityEventCard widgets', () {
    testWidgets('shrinks on null — no COMMUNITY EVENT text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeCommunityEventProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: HomeCommunityEventCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('COMMUNITY EVENT'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('shows title and Join with mock data', (tester) async {
      final card = _card(
        event: _event(
          title: 'Community Fun Run',
          startsAt: DateTime.now().add(const Duration(days: 3)),
          endsAt: DateTime.now().add(const Duration(days: 3, hours: 2)),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeCommunityEventProvider.overrideWith((ref) async => card),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: HomeCommunityEventCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMMUNITY EVENT'), findsOneWidget);
      expect(find.text('Community Fun Run'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });
  });
}
