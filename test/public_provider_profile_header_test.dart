import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/widgets/branding/cotrainr_logo.dart';
import 'package:cotrainr/widgets/common/cotrainr_back_button.dart';
import 'package:cotrainr/widgets/provider/provider_public_cover.dart';
import 'package:cotrainr/widgets/provider/public_provider_profile_header.dart';

Widget _wrap(Widget child, {ThemeData? theme, double width = 390, double textScale = 1}) {
  return MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PublicProviderIdentityHeader', () {
    testWidgets('name, username, then professional title for trainer',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PublicProviderIdentityHeader(
            name: 'Trainer 2',
            username: 'trainers',
            professionalTitle: 'Gym Trainer',
            verified: true,
          ),
        ),
      );
      expect(find.text('Trainer 2'), findsOneWidget);
      expect(find.text('@trainers'), findsOneWidget);
      expect(find.text('Gym Trainer'), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center_rounded), findsWidgets);
      expect(find.byIcon(Icons.restaurant_rounded), findsNothing);

      final nameY = tester.getTopLeft(find.text('Trainer 2')).dy;
      final userY = tester.getTopLeft(find.text('@trainers')).dy;
      final titleY = tester.getTopLeft(find.text('Gym Trainer')).dy;
      expect(nameY, lessThan(userY));
      expect(userY, lessThan(titleY));
    });

    testWidgets('nutritionist uses nutrition title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PublicProviderIdentityHeader(
            name: 'Alex Nutrition',
            username: 'alexn',
            professionalTitle: 'Sports Nutritionist',
            isNutritionist: true,
          ),
        ),
      );
      expect(find.text('Sports Nutritionist'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsWidgets);
      expect(find.byIcon(Icons.fitness_center_rounded), findsNothing);
    });

    testWidgets('long names do not overflow at 320dp and 1.5 scale',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PublicProviderIdentityHeader(
            name: 'Venkata Gopinath Reddy',
            username: 'venkata_gopinath_reddy',
            professionalTitle: 'Strength and Conditioning Coach',
            verified: true,
          ),
          width: 320,
          textScale: 1.5,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Venkata'), findsOneWidget);
    });
  });

  group('PublicProviderHeaderStats', () {
    testWidgets('order is Experience, Clients, Reviews', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PublicProviderHeaderStats(
            experienceValue: '4 yrs',
            clientsValue: '2',
            reviewsValue: '5.0',
          ),
        ),
      );
      expect(find.byIcon(Icons.work_rounded), findsOneWidget);
      expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('Location'), findsNothing);
      expect(find.text('Experience'), findsOneWidget);
      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('Reviews'), findsOneWidget);

      final expX = tester.getTopLeft(find.text('Experience')).dx;
      final clientsX = tester.getTopLeft(find.text('Clients')).dx;
      final reviewsX = tester.getTopLeft(find.text('Reviews')).dx;
      expect(expX, lessThan(clientsX));
      expect(clientsX, lessThan(reviewsX));
    });

    testWidgets('light and dark render without overflow', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          _wrap(
            const PublicProviderHeaderStats(
              experienceValue: '4 yrs',
              clientsValue: '2',
              reviewsValue: '5.0',
            ),
            theme: theme,
            width: 320,
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  testWidgets('hides watermark on 320dp and shows it on 390dp', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PublicProviderIdentityHeader(
          name: 'Trainer 2',
          username: 'trainers',
          professionalTitle: 'Gym Trainer',
        ),
        width: 320,
      ),
    );
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        const PublicProviderIdentityHeader(
          name: 'Trainer 2',
          username: 'trainers',
          professionalTitle: 'Gym Trainer',
        ),
        width: 390,
      ),
    );
    expect(
      tester.widgetList(find.byIcon(Icons.fitness_center_rounded)).length,
      greaterThan(1),
    );
  });

  testWidgets('cover widget is not required on redesigned header', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Column(
          children: [
            CotrainrBackButton(),
            PublicProviderIdentityHeader(
              name: 'Trainer 2',
              username: 'trainers',
              professionalTitle: 'Gym Trainer',
            ),
          ],
        ),
      ),
    );
    expect(find.byType(ProviderPublicCover), findsNothing);
    expect(find.byType(CotrainrLogo), findsNothing);
    expect(find.text('Where We Can Meet'), findsNothing);
    expect(find.byType(CotrainrBackButton), findsOneWidget);
  });
}
