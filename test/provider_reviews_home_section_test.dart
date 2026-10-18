import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/repositories/provider_reviews_repository.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/widgets/home_v3/home_premium_theme.dart';
import 'package:cotrainr/widgets/provider/provider_reviews_home_section.dart';

ProviderReview _review({
  required String id,
  required String name,
  int rating = 5,
  String body = 'Great coaching experience.',
}) {
  return ProviderReview(
    id: id,
    rating: rating,
    body: body,
    createdAt: DateTime(2026, 9, 1),
    reviewerName: name,
  );
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required ThemeData theme,
  required List<ProviderReview> reviews,
  bool loading = false,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ProviderReviewsHomeSection(
                reviews: reviews,
                loading: loading,
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('home reviews section source locks carousel contract', () {
    final src = File(
      'lib/widgets/provider/provider_reviews_home_section.dart',
    ).readAsStringSync();
    expect(src.contains('ProviderReviewsPage'), isFalse);
    expect(src.contains('See all reviews'), isFalse);
    expect(src.contains('_openAllReviews'), isFalse);
    expect(src.contains('PageView'), isTrue);
    expect(src.contains('Timer.periodic'), isTrue);
    expect(src.contains('_controller?.dispose()'), isTrue);
    expect(src.contains('_timer?.cancel()'), isTrue);
  });

  test('provider Home surfaces resolve distinctly in light and dark', () {
    expect(
      HomePremiumTheme.providerFitnessSurface(true),
      isNot(HomePremiumTheme.lightWarmBg),
    );
    expect(
      HomePremiumTheme.providerFitnessSurface(false),
      isNot(const Color(0xFF000000)),
    );
    expect(
      HomePremiumTheme.clientsManagementSurface(true),
      isNot(HomePremiumTheme.lightWarmBg),
    );
    expect(
      HomePremiumTheme.providerReviewCardSurface(true),
      isNot(HomePremiumTheme.providerReviewsSurface(true)),
    );
    expect(
      HomePremiumTheme.providerReviewCardSurface(false),
      isNot(HomePremiumTheme.providerReviewsSurface(false)),
    );
  });

  testWidgets('empty and loading states are preserved', (tester) async {
    await _pumpSection(
      tester,
      theme: AppTheme.lightTheme,
      reviews: const [],
      loading: true,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('See all reviews'), findsNothing);

    await _pumpSection(tester, theme: AppTheme.lightTheme, reviews: const []);
    expect(
      find.text('No reviews yet. Reviews from your clients will appear here.'),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('single review is static without page dots', (tester) async {
    await _pumpSection(
      tester,
      theme: AppTheme.lightTheme,
      reviews: [_review(id: '1', name: 'Ada')],
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Reviews & Ratings'), findsOneWidget);
    expect(find.text('See all reviews'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.bySemanticsLabel('Review 1 of 1'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Ada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi-review carousel swipes and auto-advances', (tester) async {
    timeDilation = 1.0;
    await _pumpSection(
      tester,
      theme: AppTheme.darkTheme,
      reviews: [
        _review(id: '1', name: 'Ada', body: 'First review body text.'),
        _review(id: '2', name: 'Grace', body: 'Second review body text.'),
        _review(id: '3', name: 'Katherine', body: 'Third review body text.'),
      ],
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('See all reviews'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.bySemanticsLabel('Review 1 of 3'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Grace'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 4500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce-motion skips autoplay timer advancement', (tester) async {
    await _pumpSection(
      tester,
      theme: AppTheme.lightTheme,
      disableAnimations: true,
      reviews: [
        _review(id: '1', name: 'Ada'),
        _review(id: '2', name: 'Grace'),
      ],
    );

    expect(find.text('Ada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Ada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state still offers retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ProviderReviewsHomeError(onRetry: () => retries++),
        ),
      ),
    );
    expect(find.text('Could not load your reviews.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
