import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cotrainr/services/hydration_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('HydrationLocalStore', () {
    test('applyEvent increments today total once per event id', () async {
      final store = HydrationLocalStore.instance;

      final first = await store.applyEvent(
        eventId: 'e1',
        amountMl: 250,
        source: 'notification',
      );
      final dup = await store.applyEvent(
        eventId: 'e1',
        amountMl: 250,
        source: 'notification',
      );
      final second = await store.applyEvent(
        eventId: 'e2',
        amountMl: 500,
        source: 'notification',
      );

      expect(first, 250);
      expect(dup, isNull);
      expect(second, 750);
      expect(await store.getTodayMl(), 750);
    });

    test('localDateKey uses local calendar components', () {
      final key = HydrationLocalStore.instance.localDateKey(
        DateTime(2026, 7, 22, 23, 59),
      );
      expect(key, '2026-07-22');
    });
  });
}
