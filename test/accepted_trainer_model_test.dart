import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/services/leads_models.dart';

void main() {
  group('AcceptedTrainer', () {
    test('isActive when relationshipStatus is accepted', () {
      final trainer = AcceptedTrainer(
        leadId: 'l1',
        trainerId: 't1',
        fullName: 'Alex Coach',
        connectedAt: DateTime(2026, 7, 1),
      );
      expect(trainer.isActive, isTrue);
      expect(trainer.relationshipStatus, 'accepted');
    });

    test('keeps optional profile fields', () {
      final trainer = AcceptedTrainer(
        leadId: 'l1',
        trainerId: 't1',
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
}
