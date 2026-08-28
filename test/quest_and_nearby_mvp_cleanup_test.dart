import 'dart:io';

import 'package:cotrainr/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Every production Dart file under lib/.
Iterable<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  group('Quest is disabled for the Android MVP', () {
    test('feature flag stays off', () {
      expect(FeatureFlags.enableQuest, isFalse);
      expect(FeatureFlags.questNotificationsActive, isFalse);
      expect(FeatureFlags.leaderboardsActive, isFalse);
    });

    test('legacy /quest route redirects away when the flag is off', () {
      final src = _read('lib/router/app_router.dart');
      final questRoute = src.substring(src.indexOf("path: '/quest'"));
      expect(
        questRoute.contains("FeatureFlags.enableQuest ? null : '/home'"),
        isTrue,
        reason: '/quest must redirect to /home while Quest is disabled',
      );
    });

    test('every /quest navigation call is behind the feature flag', () {
      for (final file in _libDartFiles()) {
        final src = file.readAsStringSync();
        if (!src.contains("'/quest'")) continue;
        if (file.path.replaceAll(r'\', '/').endsWith('lib/router/app_router.dart')) {
          continue;
        }
        expect(
          src.contains('FeatureFlags.enableQuest'),
          isTrue,
          reason: '${file.path} navigates to /quest without a Quest feature gate',
        );
      }
    });

    test('dormant Quest widgets with analyzer errors are removed', () {
      for (final path in const [
        'lib/widgets/quest/challenge_card.dart',
        'lib/widgets/quest/daily_quest_card.dart',
        'lib/widgets/quest/weekly_quest_card.dart',
        'lib/widgets/quest/leaderboard_view.dart',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: '$path should be deleted');
      }
    });
  });

  group('Fake nearby fitness data cannot reach production', () {
    test('static venue data file and its preview widget are gone', () {
      expect(File('lib/data/nearby_fitness_places_data.dart').existsSync(), isFalse);
      expect(File('lib/widgets/home_v3/nearby_preview_v3.dart').existsSync(), isFalse);
    });

    test('no production file imports or references the fake dataset', () {
      for (final file in _libDartFiles()) {
        final src = file.readAsStringSync();
        expect(src.contains('nearby_fitness_places_data'), isFalse,
            reason: '${file.path} imports removed fake nearby data');
        expect(src.contains('NearbyPreviewV3'), isFalse,
            reason: '${file.path} references removed NearbyPreviewV3');
        expect(src.contains('kNearbyFitnessPlaces'), isFalse,
            reason: '${file.path} references removed fake venue list');
      }
    });

    test('real partner centers preview is still what Home renders', () {
      for (final path in const [
        'lib/pages/home/home_page_v3.dart',
        'lib/pages/trainer/trainer_home_page.dart',
        'lib/pages/nutritionist/nutritionist_home_page.dart',
      ]) {
        expect(_read(path).contains('HomeCentersPreview'), isTrue);
      }
    });
  });

  group('Other disabled features stay unreachable', () {
    test('CoCircle remains flag-disabled with no route', () {
      expect(FeatureFlags.enableCoCircle, isFalse);
      expect(_read('lib/router/app_router.dart').contains("path: '/cocircle"), isFalse);
    });
  });
}
