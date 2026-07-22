import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/models/discover_filters.dart';
import 'package:cotrainr/models/provider_professional_profile.dart';
import 'package:cotrainr/models/provider_specialty_taxonomy.dart';

void main() {
  group('ProviderSpecialtyTaxonomy', () {
    test('normalizes legacy trainer labels to canonical ids', () {
      expect(ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Gym'),
          'personal_training');
      expect(ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Boxing'), 'boxing');
      expect(
        ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Calisthenics'),
        'calisthenics',
      );
      expect(ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Zumba'), 'zumba');
      expect(
        ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Strength'),
        'strength_training',
      );
    });

    test('normalizes legacy nutrition labels', () {
      expect(
        ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Weight Loss'),
        'weight_management',
      );
      expect(
        ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Clinical'),
        'clinical_nutrition',
      );
      expect(
        ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Plant-Based'),
        'plant_based_nutrition',
      );
      expect(
        ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Diabetes Care'),
        'diabetes_nutrition',
      );
    });

    test('preserves unknown custom specialties', () {
      expect(
        ProviderSpecialtyTaxonomy.normalizeSpecialtyId('Parkour Coaching'),
        'Parkour Coaching',
      );
    });

    test(
        'trainer can select multiple specialties including boxing/calisthenics/zumba',
        () {
      final saved = ProviderSpecialtyTaxonomy.normalizeList([
        'Boxing',
        'Calisthenics',
        'Zumba',
        'strength_training',
      ]);
      expect(
        saved,
        containsAll(
            ['boxing', 'calisthenics', 'zumba', 'strength_training']),
      );
      expect(ProviderSpecialtyTaxonomy.labelFor('boxing'), 'Boxing');
      expect(ProviderSpecialtyTaxonomy.labelFor('calisthenics'), 'Calisthenics');
      expect(ProviderSpecialtyTaxonomy.labelFor('zumba'), 'Zumba');
    });

    test('nutritionist specialty options are nutrition-only', () {
      final nutritionIds =
          ProviderSpecialtyTaxonomy.forRole('nutritionist').map((s) => s.id);
      final trainerIds =
          ProviderSpecialtyTaxonomy.forRole('trainer').map((s) => s.id).toSet();

      expect(nutritionIds, contains('sports_nutrition'));
      expect(nutritionIds, contains('meal_planning'));
      expect(nutritionIds, isNot(contains('boxing')));
      expect(nutritionIds, isNot(contains('zumba')));
      for (final id in nutritionIds) {
        expect(
          trainerIds.contains(id),
          isFalse,
          reason: '$id should not be a trainer specialty',
        );
      }
    });

    test('session mode labels are role-aware', () {
      expect(
        ProviderSessionModes.labelFor(
          ProviderSessionModes.online,
          role: 'nutritionist',
        ),
        'Online consultation',
      );
      expect(
        ProviderSessionModes.labelFor(
          ProviderSessionModes.providerLocation,
          role: 'nutritionist',
        ),
        'Clinic consultation',
      );
      expect(
        ProviderSessionModes.labelFor(
          ProviderSessionModes.groupSession,
          role: 'trainer',
        ),
        'Group classes',
      );
    });
  });

  group('ProviderProfessionalProfile', () {
    test('experience label hides unknown/zero and formats years', () {
      const unknown = ProviderProfessionalProfile(
        userId: 'u1',
        providerType: 'trainer',
      );
      expect(unknown.experienceLabel, isNull);
      expect(unknown.hasExperience, isFalse);

      const one = ProviderProfessionalProfile(
        userId: 'u1',
        providerType: 'trainer',
        experienceYears: 1,
      );
      expect(one.experienceLabel, '1 year experience');

      const four = ProviderProfessionalProfile(
        userId: 'u1',
        providerType: 'trainer',
        experienceYears: 4,
      );
      expect(four.experienceLabel, '4 years experience');
    });

    test(
        'completion requires headline bio specialties experience modes location',
        () {
      const empty = ProviderProfessionalProfile(
        userId: 'u1',
        providerType: 'trainer',
      );
      expect(empty.completionRatio, 0);

      const full = ProviderProfessionalProfile(
        userId: 'u1',
        providerType: 'trainer',
        professionalHeadline: 'Boxing Coach',
        bio: 'I coach beginners.',
        experienceYears: 5,
        specializationIds: ['boxing'],
        sessionModes: [ProviderSessionModes.online],
      );
      expect(full.completionRatio, 1.0);
    });

    test('languages empty means nothing to show', () {
      const p = ProviderProfessionalProfile(
        userId: 'u1',
        providerType: 'trainer',
        languages: [],
      );
      expect(p.languages, isEmpty);
    });
  });

  group('ProviderCertification privacy', () {
    test('public insert never sets verified status', () {
      final cert = ProviderCertification(
        id: '',
        providerId: 'u1',
        name: 'ACE Certified Personal Trainer',
        issuingOrganization: 'ACE',
        issueYear: 2022,
      );
      final insert = cert.toInsertJson();
      expect(insert['verification_status'], 'unverified');
      expect(insert.containsKey('credential_id'), isTrue);

      final update = cert.toUpdateJson();
      expect(
        update.containsKey('verification_status'),
        isFalse,
        reason: 'Providers must not self-set verification_status',
      );
    });

    test('fromJson supports public summary fields only', () {
      final cert = ProviderCertification.fromJson({
        'id': 'c1',
        'provider_id': 'u1',
        'name': 'Precision Nutrition Level 1',
        'issuing_organization': 'PN',
        'issue_year': 2021,
        'expiry_year': 2026,
        'verification_status': 'verified',
        'is_public': true,
      });
      expect(cert.name, 'Precision Nutrition Level 1');
      expect(cert.issuingOrganization, 'PN');
      expect(cert.verificationStatus, 'verified');
      expect(cert.credentialId, isNull);
    });
  });

  group('DiscoverFilters specialty chips', () {
    test('chip labels use taxonomy labels not raw ids', () {
      final filters = DiscoverFilters(
        categories: {'boxing', 'yoga'},
      );
      final label = filters.toChipLabel();
      expect(label.contains('Boxing'), isTrue);
      expect(label.contains('Yoga'), isTrue);
      expect(label.contains('boxing'), isFalse);
    });
  });
}
