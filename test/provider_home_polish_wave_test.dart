import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/theme/meal_tracker_tokens.dart';
import 'package:cotrainr/utils/health_metric_display.dart';

void main() {
  group('MealTrackerTokens medium emerald', () {
    test('light intake is richer than washed 0.70 and softer than neon', () {
      final mid = MealTrackerTokens.softAccent(0.84);
      final washed = MealTrackerTokens.softAccent(0.70);
      final neon = MealTrackerTokens.accent;
      expect(mid, isNot(washed));
      expect(mid, isNot(neon));
      expect(mid, isNot(MealTrackerTokens.lightBackground));
      // Distinct green identity.
      expect(mid.green, greaterThan(mid.blue));
      expect(mid.green, greaterThan(mid.red));
    });

    test('CTA gradient is stronger than intake surface', () {
      final intake = MealTrackerTokens.softAccent(0.84);
      final cta = MealTrackerTokens.softAccent(0.92);
      // Higher strength → closer to brand green (lower lightness).
      expect(cta.computeLuminance(), lessThan(intake.computeLuminance()));
      expect(
        MealTrackerTokens.primaryGradient.colors.first,
        MealTrackerTokens.softAccent(0.92),
      );
    });

    test('dark intake still resolves elevated green wash', () {
      final dark = MealTrackerTokens.intakeTileGradient(false);
      expect(dark.colors.first, isNot(MealTrackerTokens.darkBackground));
    });
  });

  group('parseMetricDouble safety', () {
    test('rejects bool without throwing', () {
      expect(parseMetricDouble(true), isNull);
      expect(parseMetricDouble(false), isNull);
      expect(parseMetricDoubleOrZero(true), 0.0);
      expect(parseMetricIntOrZero(false), 0);
    });

    test('accepts num and numeric strings', () {
      expect(parseMetricDouble(12), 12.0);
      expect(parseMetricDouble(3.5), 3.5);
      expect(parseMetricDouble('7.25'), 7.25);
      expect(parseMetricDoubleOrZero(null), 0.0);
    });

    test('weekly series tolerates bool metric cells', () {
      final series = weeklySeriesForLastSevenDays(
        rows: [
          {
            'date': DateTime.now().toIso8601String().split('T').first,
            'steps': true, // corrupt
          },
        ],
        key: 'steps',
      );
      expect(series.length, 7);
      expect(series.every((v) => v == 0.0 || v.isFinite), isTrue);
    });
  });

  group('Provider Home source contracts', () {
    late String providerSrc;

    setUpAll(() {
      providerSrc = File(
        'lib/pages/provider/provider_role_home_page.dart',
      ).readAsStringSync();
    });

    test('Messages Home section removed', () {
      expect(providerSrc.contains("title: 'Messages'"), isFalse);
      expect(providerSrc.contains('HomeNavHintCards'), isFalse);
    });

    test('community slot collapses when empty; fitness uses safe parsers', () {
      expect(providerSrc.contains('_ProviderCommunitySlot'), isTrue);
      expect(providerSrc.contains('parseMetricDoubleOrZero'), isTrue);
      expect(providerSrc.contains('weeklySeriesForLastSevenDays'), isTrue);
      expect(
        providerSrc.contains('backgroundColor: Colors.transparent'),
        isTrue,
      );
    });
  });

  group('Messaging badge source contract', () {
    test('home shell reuses unreadMessagesCountProvider with red dot', () {
      final src = File(
        'lib/pages/home/home_shell_page.dart',
      ).readAsStringSync();
      expect(src.contains('unreadMessagesCountProvider'), isTrue);
      expect(src.contains('Colors.redAccent'), isTrue);
      expect(src.contains('Unread messages'), isTrue);
    });
  });
}
