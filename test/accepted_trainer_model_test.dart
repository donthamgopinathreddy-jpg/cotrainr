import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/services/leads_models.dart';
import 'package:cotrainr/widgets/provider/provider_avatar.dart';
import 'package:flutter/material.dart';

void main() {
  group('AcceptedProvider', () {
    test('isActive when relationshipStatus is accepted', () {
      final trainer = AcceptedProvider(
        leadId: 'l1',
        providerId: 't1',
        providerType: 'trainer',
        fullName: 'Alex Coach',
        connectedAt: DateTime(2026, 7, 1),
      );
      expect(trainer.isActive, isTrue);
      expect(trainer.relationshipStatus, 'accepted');
      expect(trainer.trainerId, 't1');
      expect(trainer.roleLabel, 'Trainer');
    });

    test('nutritionist role label', () {
      final n = AcceptedProvider(
        leadId: 'l1',
        providerId: 'n1',
        providerType: 'nutritionist',
        fullName: 'Sam Diet',
        connectedAt: DateTime(2026, 7, 1),
      );
      expect(n.roleLabel, 'Nutritionist');
    });

    test('keeps optional profile fields', () {
      final trainer = AcceptedProvider(
        leadId: 'l1',
        providerId: 't1',
        providerType: 'trainer',
        fullName: 'Alex Coach',
        specializationLabel: 'Strength, HIIT',
        experienceYears: 5,
        rating: 4.8,
        reviewCount: 12,
        locationLabel: 'Lagos',
        connectedAt: DateTime(2026, 7, 1),
      );
      expect(trainer.specializationLabel, contains('HIIT'));
      expect(trainer.experienceYears, 5);
      expect(trainer.rating, 4.8);
      expect(trainer.locationLabel, 'Lagos');
    });
  });

  group('ProviderAvatar', () {
    testWidgets('uses rounded rectangle clip, not circle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProviderAvatar(
              name: 'Alex Coach',
              size: 64,
              borderRadius: 16,
            ),
          ),
        ),
      );
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.text('AC'), findsOneWidget);
    });
  });

  group('Discover connected filter logic', () {
    test('accepted ids are excluded from discover lists', () {
      final items = [
        {'id': 'a'},
        {'id': 'b'},
        {'id': 'c'},
      ];
      final accepted = {'b'};
      final visible =
          items.where((i) => !accepted.contains(i['id'])).toList();
      expect(visible.map((e) => e['id']), ['a', 'c']);
    });
  });
}
