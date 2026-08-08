import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/models/user_safety_models.dart';

void main() {
  group('UserReportReasons', () {
    test('stable ids cover product list', () {
      final ids = UserReportReasons.options.map((o) => o.id).toSet();
      expect(
        ids,
        containsAll({
          'harassment',
          'inappropriate_content',
          'spam',
          'fraud',
          'sexual_content',
          'hate_abuse',
          'impersonation',
          'unsafe_coaching',
          'other',
        }),
      );
    });

    test('labelFor returns friendly text', () {
      expect(
        UserReportReasons.labelFor(UserReportReasons.harassment),
        'Harassment or bullying',
      );
    });
  });

  group('BlockState', () {
    test('parses rpc json', () {
      final s = BlockState.fromJson({
        'i_blocked': true,
        'they_blocked': false,
        'either_blocked': true,
      });
      expect(s.iBlocked, isTrue);
      expect(s.theyBlocked, isFalse);
      expect(s.eitherBlocked, isTrue);
    });
  });
}
