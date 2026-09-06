import 'dart:io';

import 'package:cotrainr/pages/profile/map_location_picker_page.dart';
import 'package:cotrainr/pages/profile/settings/service_locations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapLocationPickerResult', () {
    test('holds lat/lng and optional label', () {
      const r = MapLocationPickerResult(
        lat: 17.385,
        lng: 78.4867,
        addressLabel: 'Hyderabad, Telangana',
      );
      expect(r.lat, 17.385);
      expect(r.lng, 78.4867);
      expect(r.addressLabel, 'Hyderabad, Telangana');
      expect(r.toLatLng().latitude, 17.385);
    });
  });

  group('MapLocationPickerPage', () {
    testWidgets('back without confirm returns null', (tester) async {
      MapLocationPickerResult? result = const MapLocationPickerResult(
        lat: 0,
        lng: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<MapLocationPickerResult>(
                    MaterialPageRoute(
                      builder: (_) => const MapLocationPickerPage(
                        initialLat: 17.3850,
                        initialLng: 78.4867,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Select location'), findsOneWidget);
      expect(find.text('Confirm location'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('confirm returns selected coordinates', (tester) async {
      MapLocationPickerResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<MapLocationPickerResult>(
                    MaterialPageRoute(
                      builder: (_) => const MapLocationPickerPage(
                        initialLat: 17.3850,
                        initialLng: 78.4867,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.lat, closeTo(17.3850, 0.0001));
      expect(result!.lng, closeTo(78.4867, 0.0001));
    });

    testWidgets('short search query does not show loading spinner',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapLocationPickerPage(
            initialLat: 17.3850,
            initialLng: 78.4867,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ServiceLocationsPage wiring', () {
    test('compact map opens shared MapLocationPickerPage', () {
      final src =
          File('lib/pages/profile/settings/service_locations_page.dart')
              .readAsStringSync();
      expect(src.contains('MapLocationPickerPage'), isTrue);
      expect(src.contains('_openFullScreenMapPicker'), isTrue);
      expect(src.contains('Expand map'), isTrue);
      expect(src.contains('InteractiveFlag.none'), isTrue);
      expect(src.contains('upsertLocation'), isTrue);
      // Confirm CTA lives on picker, not auto-save on map move.
      expect(src.contains('Confirm location'), isFalse);
    });

    test('shared ServiceLocationsPage type exists for both roles', () {
      expect(const ServiceLocationsPage(), isA<ServiceLocationsPage>());
    });

    test('home privacy still forced false on save path', () {
      final src =
          File('lib/pages/profile/settings/service_locations_page.dart')
              .readAsStringSync();
      expect(
        src.contains(
          'if (_selectedType == LocationType.home) _isPublicExact = false',
        ),
        isTrue,
      );
    });

    test('saved-location action row uses compact icons + flexible Set Primary', () {
      final src =
          File('lib/pages/profile/settings/service_locations_page.dart')
              .readAsStringSync();
      expect(src.contains('_IconActionButton'), isTrue);
      expect(src.contains("semanticLabel: 'Edit location'"), isTrue);
      expect(src.contains("semanticLabel: 'Delete location'"), isTrue);
      expect(src.contains("label: 'Set Primary'"), isTrue);
      expect(src.contains('Flexible('), isTrue);
      // Primary locations: no duplicate Primary action in the row.
      expect(src.contains("label: 'Primary'"), isFalse);
      expect(src.contains("label: 'Edit'"), isFalse);
      expect(src.contains("label: 'Delete'"), isFalse);
    });
  });
}
