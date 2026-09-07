import 'dart:io';

import 'package:cotrainr/core/auth/user_role.dart';
import 'package:cotrainr/theme/cotrainr_identity_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PassIdentity resolution', () {
    test('trainer always burgundy regardless of plan label', () {
      final id = PassIdentity.resolve(role: UserRole.trainer, planLabel: 'Free');
      expect(id.id, 'trainer');
      expect(id.accent, CotrainrIdentityColors.trainerAccent);
      expect(
        id.cardGradient.colors.first,
        CotrainrIdentityColors.trainerStart,
      );
      expect(id.cardGradient.colors.last, CotrainrIdentityColors.trainerEnd);
    });

    test('nutritionist always emerald regardless of plan label', () {
      final id = PassIdentity.resolve(
        role: UserRole.nutritionist,
        planLabel: 'Ultimate',
      );
      expect(id.id, 'nutritionist');
      expect(id.accent, CotrainrIdentityColors.nutritionistAccent);
      expect(
        id.cardGradient.colors.first,
        CotrainrIdentityColors.nutritionistStart,
      );
    });

    test('client Free → silver', () {
      final id = PassIdentity.resolve(role: UserRole.client, planLabel: 'Free');
      expect(id.id, 'free');
      expect(id.accent, CotrainrIdentityColors.freeEnd);
      expect(id.cardGradient.colors.first, CotrainrIdentityColors.freeStart);
    });

    test('client Basic → orange', () {
      final id =
          PassIdentity.resolve(role: UserRole.client, planLabel: 'Basic');
      expect(id.id, 'basic');
      expect(id.accent, CotrainrIdentityColors.basicStart);
    });

    test('client Ultimate / premium → black+gold', () {
      expect(
        PassIdentity.resolve(role: UserRole.client, planLabel: 'Ultimate').id,
        'ultimate',
      );
      expect(
        PassIdentity.resolve(role: UserRole.client, planLabel: 'premium').id,
        'ultimate',
      );
      final id =
          PassIdentity.resolve(role: UserRole.client, planLabel: 'Ultimate');
      expect(id.accent, CotrainrIdentityColors.ultimateGold);
      expect(id.highlight, CotrainrIdentityColors.ultimateGold);
      expect(id.ctaBackground, CotrainrIdentityColors.ultimateGold);
      expect(id.ctaForeground, const Color(0xFF141414));
    });

    test('locked colour constants', () {
      expect(CotrainrIdentityColors.freeStart, const Color(0xFF555B63));
      expect(CotrainrIdentityColors.freeEnd, const Color(0xFF8A9098));
      expect(CotrainrIdentityColors.basicStart, const Color(0xFFF65A00));
      expect(CotrainrIdentityColors.basicEnd, const Color(0xFFFF9D24));
      expect(CotrainrIdentityColors.ultimateStart, const Color(0xFF0D0D0F));
      expect(CotrainrIdentityColors.ultimateEnd, const Color(0xFF252529));
      expect(CotrainrIdentityColors.ultimateGold, const Color(0xFFD9AD4A));
      expect(CotrainrIdentityColors.trainerStart, const Color(0xFF54152D));
      expect(CotrainrIdentityColors.trainerEnd, const Color(0xFFA62C5A));
      expect(CotrainrIdentityColors.trainerAccent, const Color(0xFFF08AAF));
      expect(CotrainrIdentityColors.trainerWatermark, const Color(0xFF3A0D20));
      expect(CotrainrIdentityColors.nutritionistStart, const Color(0xFF087A55));
      expect(CotrainrIdentityColors.nutritionistEnd, const Color(0xFF18A875));
      expect(
        CotrainrIdentityColors.nutritionistAccent,
        const Color(0xFF6FE0B3),
      );
    });

    test('SubscriptionPlanColors stay client-only (no trainer/nutritionist)', () {
      expect(SubscriptionPlanColors.accentFor('free'), PassIdentity.free.accent);
      expect(
        SubscriptionPlanColors.accentFor('basic'),
        PassIdentity.basic.accent,
      );
      expect(
        SubscriptionPlanColors.accentFor('premium'),
        PassIdentity.ultimate.accent,
      );
    });
  });

  group('Member Pass presentation contracts', () {
    late String src;

    setUpAll(() {
      src = File('lib/pages/profile/cotrainr_pass_page.dart').readAsStringSync();
    });

    test('PASS ID on card with copy icon only', () {
      expect(src.contains("'PASS ID'"), isTrue);
      expect(src.contains('MEMBER ID'), isFalse);
      expect(src.contains('Icons.copy_rounded'), isTrue);
      expect(src.contains("'Copy Pass ID'"), isTrue);
      expect(src.contains('Pass ID copied'), isTrue);
      expect(src.contains("'Copy ID'"), isFalse);
      expect(src.contains("'Your Pass ID'"), isFalse);
    });

    test('full Pass ID never uses ellipsis truncation', () {
      // Pass ID Text must not truncate with TextOverflow.ellipsis.
      final passIdBlock = src.split("'PASS ID'")[1].split('MEMBER SINCE')[0];
      expect(passIdBlock.contains('TextOverflow.ellipsis'), isFalse);
      expect(passIdBlock.contains('info.passId'), isTrue);
      expect(passIdBlock.contains('softWrap: true'), isTrue);
      expect(passIdBlock.contains('Icons.copy_rounded'), isTrue);
    });

    test('Academy removed; Partner Centres + Verification retained', () {
      expect(src.contains('Cotrainr Academy'), isFalse);
      expect(src.contains('Icons.school_outlined'), isFalse);
      expect(src.contains('Icons.storefront_rounded'), isTrue);
      expect(src.contains('Icons.fitness_center_rounded'), isFalse);
      expect(src.contains('Membership Verification'), isTrue);
      expect(src.contains('Partner Centres'), isTrue);
      expect(src.contains('Become a Partner Centre'), isTrue);
      expect(src.contains('Cotrainr Pass Terms'), isTrue);
      expect(src.contains('Available'), isTrue);
      expect(src.contains('CotrainrIdentityColors.availableGreen'), isTrue);
    });

    test('role-aware about copy and provider plan gate', () {
      expect(src.contains('permanent Trainer identity'), isTrue);
      expect(src.contains('permanent Nutritionist identity'), isTrue);
      expect(src.contains('permanent member identity'), isTrue);
      expect(src.contains('if (_isClient)'), isTrue);
      expect(src.contains('YOUR PLAN'), isTrue);
      expect(src.contains('PassIdentity.resolve'), isTrue);
    });

    test('role-neutral Partner Centres + verification copy', () {
      expect(
        src.contains(
          'Verify your Cotrainr Pass at participating gyms, studios and fitness centres',
        ),
        isTrue,
      );
      expect(
        src.contains(
          'Your Pass ID securely identifies your Cotrainr account where verification is required.',
        ),
        isTrue,
      );
      expect(src.contains('Verify your membership at participating'), isFalse);
    });
  });
}
