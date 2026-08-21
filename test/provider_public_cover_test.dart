import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/utils/provider_cover_url.dart';
import 'package:cotrainr/widgets/branding/cotrainr_logo.dart';
import 'package:cotrainr/widgets/provider/provider_avatar.dart';
import 'package:cotrainr/widgets/provider/provider_public_cover.dart';

Widget _harness({
  required ThemeData theme,
  String? coverUrl,
  String? avatarUrl,
  Widget? avatar,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: ProviderPublicCover(
              coverUrl: coverUrl,
              avatarUrl: avatarUrl,
            ),
          ),
          ?avatar,
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveProviderCoverUrl', () {
    test('returns http cover and ignores avatar', () {
      expect(
        resolveProviderCoverUrl(
          coverUrl: 'https://cdn.example/covers/t1.jpg',
          avatarUrl: 'https://cdn.example/avatars/t1.jpg',
        ),
        'https://cdn.example/covers/t1.jpg',
      );
    });

    test('empty string and null become fallback', () {
      expect(resolveProviderCoverUrl(coverUrl: null), isNull);
      expect(resolveProviderCoverUrl(coverUrl: ''), isNull);
      expect(resolveProviderCoverUrl(coverUrl: '   '), isNull);
    });

    test('does not use avatar_url as cover', () {
      const avatar = 'https://cdn.example/avatars/n1.jpg';
      expect(
        resolveProviderCoverUrl(coverUrl: avatar, avatarUrl: avatar),
        isNull,
      );
      expect(
        resolveProviderCoverUrl(coverUrl: null, avatarUrl: avatar),
        isNull,
      );
    });

    test('rejects malformed URLs', () {
      expect(resolveProviderCoverUrl(coverUrl: 'not-a-url'), isNull);
      expect(resolveProviderCoverUrl(coverUrl: 'ftp://x/cover.jpg'), isNull);
    });
  });

  group('ProviderPublicCover', () {
    testWidgets('trainer with cover image uses that URL not avatar',
        (tester) async {
      const cover = 'https://cdn.example/covers/trainer.jpg';
      const avatar = 'https://cdn.example/avatars/trainer.jpg';
      await tester.pumpWidget(
        _harness(
          theme: AppTheme.lightTheme,
          coverUrl: cover,
          avatarUrl: avatar,
          avatar: const ProviderAvatar(imageUrl: avatar, name: 'Trainer'),
        ),
      );
      final image = tester.widget<CachedNetworkImage>(
        find.descendant(
          of: find.byType(ProviderPublicCover),
          matching: find.byType(CachedNetworkImage),
        ),
      );
      expect(image.imageUrl, cover);
      expect(image.imageUrl, isNot(avatar));
    });

    testWidgets('nutritionist with cover image uses that URL not avatar',
        (tester) async {
      const cover = 'https://cdn.example/covers/nutritionist.jpg';
      const avatar = 'https://cdn.example/avatars/nutritionist.jpg';
      await tester.pumpWidget(
        _harness(
          theme: AppTheme.darkTheme,
          coverUrl: cover,
          avatarUrl: avatar,
          avatar: const ProviderAvatar(imageUrl: avatar, name: 'Nutritionist'),
        ),
      );
      final image = tester.widget<CachedNetworkImage>(
        find.descendant(
          of: find.byType(ProviderPublicCover),
          matching: find.byType(CachedNetworkImage),
        ),
      );
      expect(image.imageUrl, cover);
      expect(image.imageUrl, isNot(avatar));
    });

    testWidgets('trainer without cover shows Cotrainr logo fallback',
        (tester) async {
      await tester.pumpWidget(
        _harness(theme: AppTheme.lightTheme, coverUrl: null),
      );
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(CotrainrLogo), findsOneWidget);
      expect(find.byType(ProviderCoverFallback), findsOneWidget);
      expect(find.textContaining('No cover'), findsNothing);
      expect(find.textContaining('cover image'), findsNothing);
    });

    testWidgets('nutritionist without cover shows Cotrainr logo fallback',
        (tester) async {
      await tester.pumpWidget(
        _harness(theme: AppTheme.darkTheme, coverUrl: null),
      );
      expect(find.byType(CotrainrLogo), findsOneWidget);
      expect(find.textContaining('No cover'), findsNothing);
    });

    testWidgets('empty string uses fallback', (tester) async {
      await tester.pumpWidget(
        _harness(theme: AppTheme.lightTheme, coverUrl: ''),
      );
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(CotrainrLogo), findsOneWidget);
    });

    testWidgets('invalid image URL falls back to logo', (tester) async {
      await tester.pumpWidget(
        _harness(
          theme: AppTheme.lightTheme,
          coverUrl: 'https://127.0.0.1:1/missing-cover.jpg',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CotrainrLogo), findsWidgets);
      expect(find.textContaining('No cover'), findsNothing);
    });

    testWidgets('avatar remains separate from cover', (tester) async {
      await tester.pumpWidget(
        _harness(
          theme: AppTheme.lightTheme,
          coverUrl: null,
          avatarUrl: 'https://cdn.example/avatars/only.jpg',
          avatar: const ProviderAvatar(
            imageUrl: 'https://cdn.example/avatars/only.jpg',
            name: 'Alex',
          ),
        ),
      );
      expect(find.byType(ProviderAvatar), findsOneWidget);
      expect(find.byType(ProviderPublicCover), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProviderPublicCover),
          matching: find.byType(CachedNetworkImage),
        ),
        findsNothing,
      );
      expect(find.byType(CotrainrLogo), findsOneWidget);
    });

    testWidgets('light and dark fallbacks keep the logo', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(_harness(theme: theme));
        expect(find.byType(CotrainrLogo), findsOneWidget);
        expect(find.byIcon(Icons.broken_image), findsNothing);
        expect(find.byIcon(Icons.fitness_center_rounded), findsNothing);
      }
    });

    testWidgets('light fallback uses light surface, larger black logo at 50%',
        (tester) async {
      await tester.pumpWidget(_harness(theme: AppTheme.lightTheme));
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ProviderCoverFallback),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, DesignTokens.lightMutedCardBackground);
      expect(find.byType(ColorFiltered), findsOneWidget);
      final logo = tester.widget<CotrainrLogo>(find.byType(CotrainrLogo));
      expect(logo.height, 88);
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(ProviderCoverFallback),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);
    });
  });
}
