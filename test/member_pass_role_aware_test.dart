import 'dart:io';

import 'package:cotrainr/core/auth/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Member Pass role-aware UI contracts', () {
    late String src;

    setUpAll(() {
      src = File('lib/pages/profile/cotrainr_pass_page.dart').readAsStringSync();
    });

    test('uses canonical currentUserProvider role source', () {
      expect(src.contains('currentUserProvider'), isTrue);
      expect(src.contains('UserRole'), isTrue);
      expect(src.contains('role?.isProvider'), isTrue);
    });

    test('client shows PLAN path and Your Plan section', () {
      expect(src.contains("'PLAN'"), isTrue);
      expect(src.contains('YOUR PLAN'), isTrue);
      expect(src.contains('_YourPlanCard'), isTrue);
      expect(src.contains('View plans'), isFalse); // label lives in MemberPlanView
      expect(src.contains('if (_isClient)'), isTrue);
    });

    test('trainer shows ROLE → Trainer and hides plan section', () {
      expect(src.contains("case UserRole.trainer:"), isTrue);
      expect(src.contains("return 'Trainer'"), isTrue);
      expect(src.contains("metaLabel = showRole ? 'ROLE' : 'PLAN'"), isTrue);
      expect(src.contains('permanent Trainer identity'), isTrue);
    });

    test('nutritionist shows ROLE → Nutritionist', () {
      expect(src.contains("case UserRole.nutritionist:"), isTrue);
      expect(src.contains("return 'Nutritionist'"), isTrue);
      expect(src.contains('permanent Nutritionist identity'), isTrue);
      expect(src.contains('FittedBox'), isTrue);
    });

    test('providers skip subscription refresh on resume', () {
      expect(
        src.contains('resumed && _info != null && _isClient'),
        isTrue,
      );
      expect(src.contains('if (!_isClient) return;'), isTrue);
    });

    test('pass ID and Partner Centres remain', () {
      expect(src.contains('passId'), isTrue);
      expect(src.contains('Partner Centres'), isTrue);
      expect(src.contains('Find Centres'), isTrue);
      expect(src.contains('MEMBER ID'), isTrue);
    });

    test('canonical UserRole values unchanged', () {
      final roleSrc = File('lib/core/auth/user_role.dart').readAsStringSync();
      expect(roleSrc.contains("case 'client':"), isTrue);
      expect(roleSrc.contains("case 'trainer':"), isTrue);
      expect(roleSrc.contains("case 'nutritionist':"), isTrue);
      expect(UserRole.client.dbValue, 'client');
      expect(UserRole.trainer.dbValue, 'trainer');
      expect(UserRole.nutritionist.dbValue, 'nutritionist');
    });
  });
}
