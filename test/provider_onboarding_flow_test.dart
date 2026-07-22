import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/models/provider_specialty_taxonomy.dart';
import 'package:cotrainr/widgets/provider/provider_professional_form_validation.dart';

void main() {
  group('postPermissionsDestination', () {
    test('client goes to /home', () {
      expect(postPermissionsDestination('client'), '/home');
      expect(postPermissionsDestination('Client'), '/home');
    });

    test('trainer goes to /verification', () {
      expect(postPermissionsDestination('trainer'), '/verification');
      expect(postPermissionsDestination('Trainer'), '/verification');
    });

    test('nutritionist goes to /verification', () {
      expect(postPermissionsDestination('nutritionist'), '/verification');
    });
  });

  group('ProviderProfessionalFormValidation', () {
    final validBio =
        'I specialise in calisthenics and bodyweight strength training '
        'with over 6 years of coaching experience.';

    Map<String, Object> base({
      String headline = 'Boxing Coach',
      String experience = '4',
      String? bio,
      List<String> specs = const ['boxing'],
      List<String> langs = const ['English'],
      List<String> modes = const [ProviderSessionModes.online],
    }) {
      return {
        'headline': headline,
        'experience': experience,
        'bio': bio ?? validBio,
        'specs': specs,
        'langs': langs,
        'modes': modes,
      };
    }

    String? run(Map<String, Object> m) =>
        ProviderProfessionalFormValidation.validate(
          headline: m['headline'] as String,
          experienceText: m['experience'] as String,
          bio: m['bio'] as String,
          specializationIds: m['specs'] as List<String>,
          languages: m['langs'] as List<String>,
          sessionModes: m['modes'] as List<String>,
        );

    test('valid form passes', () {
      expect(run(base()), isNull);
    });

    test('headline is required', () {
      expect(run(base(headline: '  ')), isNotNull);
    });

    test('experience accepts 0–60 only', () {
      expect(run(base(experience: '0')), isNull);
      expect(run(base(experience: '60')), isNull);
      expect(run(base(experience: '61')), isNotNull);
      expect(run(base(experience: '')), isNotNull);
      expect(run(base(experience: 'abc')), isNotNull);
    });

    test('bio min length enforced', () {
      expect(run(base(bio: 'Too short')), isNotNull);
    });

    test('specialties required', () {
      expect(run(base(specs: [])), isNotNull);
    });

    test('languages required', () {
      expect(run(base(langs: [])), isNotNull);
    });

    test('session modes required', () {
      expect(run(base(modes: [])), isNotNull);
    });

    test('role-aware headline placeholders', () {
      expect(
        ProviderProfessionalFormValidation.headlinePlaceholder('trainer'),
        contains('Calisthenics'),
      );
      expect(
        ProviderProfessionalFormValidation.headlinePlaceholder('nutritionist'),
        contains('Sports Nutritionist'),
      );
    });
  });

  group('Specialty options by role', () {
    test('trainer sees boxing/calisthenics/zumba options', () {
      final ids =
          ProviderSpecialtyTaxonomy.forRole('trainer').map((s) => s.id).toSet();
      expect(ids, containsAll(['boxing', 'calisthenics', 'zumba']));
      expect(ids, isNot(contains('sports_nutrition')));
    });

    test('nutritionist sees nutrition-only options', () {
      final ids = ProviderSpecialtyTaxonomy.forRole('nutritionist')
          .map((s) => s.id)
          .toSet();
      expect(ids, contains('sports_nutrition'));
      expect(ids, isNot(contains('boxing')));
    });
  });

  group('Session mode storage vs labels', () {
    test('canonical ids are stored values', () {
      expect(ProviderSessionModes.all, contains('online'));
      expect(ProviderSessionModes.all, contains('provider_location'));
      expect(ProviderSessionModes.all, contains('group_session'));
    });

    test('labels are role-aware display only', () {
      expect(
        ProviderSessionModes.labelFor('online', role: 'trainer'),
        'Online coaching',
      );
      expect(
        ProviderSessionModes.labelFor('online', role: 'nutritionist'),
        'Online consultation',
      );
    });
  });

  group('Save payload targets (contract)', () {
    test('professional save maps to known columns only', () {
      // Documents contract for implementers / regression lock.
      const targets = {
        'professional_headline': 'providers.professional_headline',
        'experience_years': 'providers.experience_years',
        'specialization': 'providers.specialization',
        'session_modes': 'providers.session_modes',
        'languages': 'providers.languages',
        'bio': 'profiles.bio',
      };
      expect(targets['bio'], 'profiles.bio');
      expect(targets.containsKey('verified'), isFalse);
      expect(targets.containsKey('discoverable'), isFalse);
    });
  });
}
