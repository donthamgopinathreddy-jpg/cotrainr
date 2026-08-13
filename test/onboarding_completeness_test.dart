import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/core/auth/onboarding_completeness.dart';
import 'package:cotrainr/core/auth/onboarding_state_service.dart';
import 'package:cotrainr/core/auth/signup_error_mapper.dart';
import 'package:cotrainr/core/auth/signup_mode.dart';

OnboardingSnapshot snap({
  String? username = 'user_one',
  String? role = 'client',
  bool hasDob = true,
  String? gender = 'Male',
  num? heightCm = 170,
  num? weightKg = 70,
  List<String> goals = const ['Weight Loss'],
  bool legal = true,
  List<String> specialties = const [],
  bool legacy = false,
}) {
  return OnboardingSnapshot(
    username: username,
    role: role,
    dateOfBirth: hasDob ? DateTime(2000, 1, 1) : null,
    gender: gender,
    heightCm: heightCm,
    weightKg: weightKg,
    fitnessGoals: goals,
    hasCurrentLegal: legal,
    providerSpecialties: specialties,
    isLegacyBodyComplete: legacy,
  );
}

void main() {
  group('SignupMode', () {
    test('email and social are distinct shared-onboarding modes', () {
      expect(SignupMode.email, isNot(SignupMode.social));
      expect(SignupMode.values, containsAll([SignupMode.email, SignupMode.social]));
    });
  });

  group('OnboardingCompleteness', () {
    test('username only → incomplete', () {
      final state = OnboardingCompleteness.evaluate(
        const OnboardingSnapshot(username: 'only_user'),
      );
      expect(state.isComplete, isFalse);
      expect(state.missing, containsAll(['role', 'dob', 'gender', 'height', 'weight']));
    });

    test('username + role only → incomplete', () {
      final state = OnboardingCompleteness.evaluate(
        const OnboardingSnapshot(username: 'only_user', role: 'client'),
      );
      expect(state.isComplete, isFalse);
      expect(state.missing, containsAll(['dob', 'gender', 'height', 'weight']));
    });

    test('missing DOB → incomplete', () {
      final state = OnboardingCompleteness.evaluate(
        snap(hasDob: false),
      );
      expect(state.isComplete, isFalse);
      expect(state.missing, contains('dob'));
    });

    test('missing height → incomplete', () {
      final state = OnboardingCompleteness.evaluate(snap(heightCm: null));
      expect(state.isComplete, isFalse);
      expect(state.missing, contains('height'));
    });

    test('missing weight → incomplete', () {
      final state = OnboardingCompleteness.evaluate(snap(weightKg: null));
      expect(state.isComplete, isFalse);
      expect(state.missing, contains('weight'));
    });

    test('missing legal → incomplete', () {
      final state = OnboardingCompleteness.evaluate(snap(legal: false));
      expect(state.isComplete, isFalse);
      expect(state.missing, contains('legal'));
    });

    test('missing required goals → incomplete', () {
      final state = OnboardingCompleteness.evaluate(snap(goals: const []));
      expect(state.isComplete, isFalse);
      expect(state.missing, contains('goals'));
    });

    test('provider missing specialties → incomplete', () {
      final trainer = OnboardingCompleteness.evaluate(
        snap(role: 'trainer', specialties: const []),
      );
      final nutritionist = OnboardingCompleteness.evaluate(
        snap(role: 'nutritionist', specialties: const []),
      );
      expect(trainer.isComplete, isFalse);
      expect(trainer.missing, contains('specialties'));
      expect(nutritionist.isComplete, isFalse);
      expect(nutritionist.missing, contains('specialties'));
    });

    test('fully valid Client → complete', () {
      final state = OnboardingCompleteness.evaluate(snap());
      expect(state.isComplete, isTrue);
      expect(state.missing, isEmpty);
    });

    test('fully valid Provider → complete', () {
      final state = OnboardingCompleteness.evaluate(
        snap(role: 'trainer', specialties: const ['Strength']),
      );
      expect(state.isComplete, isTrue);
      expect(state.missing, isEmpty);
    });

    test('legacy body-complete user without goals/legal is complete', () {
      final state = OnboardingCompleteness.evaluate(
        snap(goals: const [], legal: false, legacy: true),
      );
      expect(state.isComplete, isTrue);
    });

    test('client does not require specialties', () {
      final state = OnboardingCompleteness.evaluate(
        snap(role: 'client', specialties: const []),
      );
      expect(state.missing, isNot(contains('specialties')));
      expect(state.isComplete, isTrue);
    });
  });

  group('OnboardingStateService.parse', () {
    test('parses complete row', () {
      final state = OnboardingStateService.parse({
        'is_complete': true,
        'missing': <String>[],
      });
      expect(state.isComplete, isTrue);
      expect(state.missing, isEmpty);
    });

    test('incomplete when missing codes present', () {
      final state = OnboardingStateService.parse({
        'is_complete': true,
        'missing': ['username', 'dob'],
      });
      expect(state.isComplete, isFalse);
      expect(state.missing, ['username', 'dob']);
    });

    test('list envelope from PostgREST', () {
      final state = OnboardingStateService.parse([
        {
          'is_complete': false,
          'missing': ['goals', 'legal'],
        }
      ]);
      expect(state.isComplete, isFalse);
      expect(state.missing, ['goals', 'legal']);
    });
  });

  group('SignupErrorMapper social finalize', () {
    test('invalid role', () {
      final msg = SignupErrorMapper.map(Exception('Invalid role'));
      expect(msg, SignupErrorMapper.invalidRole);
    });

    test('missing required fields', () {
      expect(
        SignupErrorMapper.map(Exception('Date of birth is required')),
        SignupErrorMapper.missingRequired,
      );
      expect(
        SignupErrorMapper.map(Exception('Height is required')),
        SignupErrorMapper.missingRequired,
      );
      expect(
        SignupErrorMapper.map(Exception('At least one fitness goal is required')),
        SignupErrorMapper.missingRequired,
      );
    });

    test('legal failure', () {
      final msg = SignupErrorMapper.map(
        Exception('Legal acceptance versions are outdated'),
      );
      expect(msg, SignupErrorMapper.legalRequired);
    });
  });
}
