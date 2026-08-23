import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cotrainr/providers/accepted_client_trainers_provider.dart';
import 'package:cotrainr/providers/partner_centers_provider.dart';
import 'package:cotrainr/providers/profile_role_provider.dart';
import 'package:cotrainr/providers/unread_video_session_notifications_provider.dart';
import 'package:cotrainr/services/leads_models.dart';
import 'package:cotrainr/repositories/partner_centers_repository.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/widgets/home_v3/hero_header_v3.dart';
import 'package:cotrainr/widgets/home_v3/home_centers_preview.dart';
import 'package:cotrainr/widgets/home_v3/quick_access_v3.dart';
import 'package:cotrainr/widgets/home_v3/unified_metrics_tile_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

PartnerCenterDiscoverItem _center({
  required String id,
  required String name,
  String type = 'Gym',
  String city = 'Hyderabad',
  String? offer,
  String? logo,
}) {
  return PartnerCenterDiscoverItem(
    id: id,
    name: name,
    businessType: type,
    city: city,
    country: 'IN',
    addressLine1: '1 Main',
    offerTitle: offer,
    logoUrl: logo,
  );
}

class _FixedUser extends CurrentUserNotifier {
  _FixedUser(this.user);
  final CurrentUser user;

  @override
  Future<CurrentUser?> build() async => user;
}

CurrentUser _user(String role) => CurrentUser(
      id: 'u1',
      role: role,
      fullName: 'Ada',
    );

class _EmptyTrainers extends AcceptedClientTrainersNotifier {
  @override
  Future<List<AcceptedTrainer>> build() async => const [];
}

class _EmptyNutritionists extends AcceptedClientNutritionistsNotifier {
  @override
  Future<List<AcceptedProvider>> build() async => const [];
}

List<Override> _exploreOverrides(CurrentUser user) {
  return [
    currentUserProvider.overrideWith(() => _FixedUser(user)),
    acceptedClientTrainersProvider.overrideWith(_EmptyTrainers.new),
    acceptedClientNutritionistsProvider.overrideWith(_EmptyNutritionists.new),
    acceptedClientTrainersCountProvider.overrideWith((ref) => 0),
    acceptedClientNutritionistsCountProvider.overrideWith((ref) => 0),
    unreadVideoSessionNotificationsProvider.overrideWith((ref) async => 0),
  ];
}

List<UnifiedMetricViewModel> _dummyMetrics() {
  UnifiedMetricViewModel m(String label) => UnifiedMetricViewModel(
        label: label,
        icon: Icons.directions_walk,
        ringGradient: const LinearGradient(colors: [Colors.orange, Colors.red]),
        barColor: Colors.orange,
        progress: 0.4,
        mainValue: '4000',
        subValue: 'of 10000 steps',
        weekly: const [0, 0, 0, 0, 0, 0, 0],
        todayValue: 4000,
        goalValue: 10000,
      );
  return [
    m('STEPS'),
    m('ACTIVE CALORIES'),
    m('WATER'),
    m('DISTANCE'),
  ];
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required List<PartnerCenterDiscoverItem> centers,
  ThemeData? theme,
  Size size = const Size(390, 844),
  double textScale = 1,
  VoidCallback? onSeeAll,
  ValueChanged<PartnerCenterDiscoverItem>? onOpen,
  String role = 'client',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homePartnerCentersProvider.overrideWith((ref) async => centers),
        currentUserProvider.overrideWith(() => _FixedUser(_user(role))),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: HomeCentersPreview(
              onSeeAll: onSeeAll ?? () {},
              onOpenCenter: onOpen ?? (_) {},
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
  GoogleFonts.config.allowRuntimeFetching = false;

  test('fake nearby data is not used by shipping Home', () {
    for (final path in [
      'lib/pages/home/home_page_v3.dart',
      'lib/pages/trainer/trainer_home_page.dart',
      'lib/pages/nutritionist/nutritionist_home_page.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('nearby_fitness_places_data'), isFalse);
      expect(src.contains('NearbyPreviewV3'), isFalse);
      expect(src.contains('Power Gym'), isFalse);
      expect(src.contains('Zen Yoga Studio'), isFalse);
      expect(src.contains('HomeCentersPreview'), isTrue);
    }
  });

  test('hero has no Unsplash fallback URL', () {
    final src = File('lib/widgets/home_v3/hero_header_v3.dart').readAsStringSync();
    expect(src.toLowerCase().contains('unsplash'), isFalse);
    expect(src.contains('_kDefaultHeroImageUrl'), isFalse);
  });

  test('canonical role drives Explore; provider video copy is not client copy', () {
    final explore = File('lib/widgets/home_v3/quick_access_v3.dart').readAsStringSync();
    expect(explore.contains("userMetadata?['role']"), isFalse);
    expect(explore.contains('currentUserProvider'), isTrue);
    expect(explore.contains('Schedule and manage video sessions'), isTrue);
  });

  test('provider first-load health sync uses metricsSyncService.syncNow', () {
    for (final path in [
      'lib/pages/trainer/trainer_home_page.dart',
      'lib/pages/nutritionist/nutritionist_home_page.dart',
      'lib/pages/home/home_page_v3.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('metricsSyncServiceProvider'), isTrue);
      expect(src.contains('syncNow()'), isTrue);
    }
  });

  test('goal loading does not start from confirmed default UI', () {
    for (final path in [
      'lib/pages/home/home_page_v3.dart',
      'lib/pages/trainer/trainer_home_page.dart',
      'lib/pages/nutritionist/nutritionist_home_page.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('goalsLoading: !_goalsReady'), isTrue);
    }
  });

  test('provider name does not use Trainer/Nutritionist placeholder while loading', () {
    final trainer = File('lib/pages/trainer/trainer_home_page.dart').readAsStringSync();
    final nutritionist =
        File('lib/pages/nutritionist/nutritionist_home_page.dart').readAsStringSync();
    expect(trainer.contains("String _trainerName = 'Trainer'"), isFalse);
    expect(nutritionist.contains("String _nutritionistName = 'Nutritionist'"), isFalse);
    expect(trainer.contains('usernameLoading: _nameLoading'), isTrue);
    expect(nutritionist.contains('usernameLoading: _nameLoading'), isTrue);
  });

  test('request accept/decline invalidates Home counts', () {
    final notes =
        File('lib/pages/notifications/notification_page.dart').readAsStringSync();
    final clients =
        File('lib/pages/provider/provider_my_clients_page.dart').readAsStringSync();
    expect('invalidateProviderHomeCounts'.allMatches(notes).length, greaterThanOrEqualTo(2));
    expect(clients.contains('invalidateProviderHomeCounts'), isTrue);
  });

  test('preview count is 3 on compact and 5 on wider Home', () {
    expect(homeCentersPreviewCountForWidth(320), 3);
    expect(homeCentersPreviewCountForWidth(360), 3);
    expect(homeCentersPreviewCountForWidth(375), 3);
    expect(homeCentersPreviewCountForWidth(390), 5);
    expect(homeCentersPreviewCountForWidth(430), 5);
  });

  testWidgets('real center renders on Member Home preview', (tester) async {
    await _pumpPreview(
      tester,
      role: 'client',
      centers: [_center(id: 'c1', name: 'Cult Fitness Hub', offer: '10% off')],
    );
    expect(find.text('Cult Fitness Hub'), findsOneWidget);
    expect(find.text('Gym · Hyderabad'), findsOneWidget);
    expect(find.text('Cotrainr Partner'), findsOneWidget);
    expect(find.text('Offer'), findsOneWidget);
    expect(find.text('Power Gym'), findsNothing);
    expect(find.text('Zen Yoga Studio'), findsNothing);
    expect(find.textContaining('Open'), findsNothing);
    expect(find.textContaining('km'), findsNothing);
    expect(find.textContaining('4.7'), findsNothing);
  });

  testWidgets('real center renders on Trainer and Nutritionist Home preview',
      (tester) async {
    for (final role in ['trainer', 'nutritionist']) {
      await _pumpPreview(
        tester,
        role: role,
        centers: [_center(id: 'c1', name: 'Cult Fitness Hub')],
      );
      expect(find.text('Cult Fitness Hub'), findsOneWidget);
      expect(find.text('Power Gym'), findsNothing);
    }
  });

  testWidgets('max preview count is respected', (tester) async {
    final six = List.generate(
      6,
      (i) => _center(id: '$i', name: 'Center $i'),
    );
    await _pumpPreview(tester, centers: six, size: const Size(320, 640));
    expect(find.text('Center 0'), findsOneWidget);
    expect(find.text('Center 2'), findsOneWidget);
    expect(find.text('Center 3'), findsNothing);

    await _pumpPreview(tester, centers: six, size: const Size(412, 844));
    expect(find.text('Center 4'), findsOneWidget);
    expect(find.text('Center 5'), findsNothing);
  });

  testWidgets('See all and center tap are not dead', (tester) async {
    var seeAll = 0;
    PartnerCenterDiscoverItem? opened;
    await _pumpPreview(
      tester,
      centers: [_center(id: 'c1', name: 'Cult Fitness Hub')],
      onSeeAll: () => seeAll++,
      onOpen: (c) => opened = c,
    );
    await tester.tap(find.text('See all'));
    await tester.pump();
    expect(seeAll, 1);

    await tester.tap(find.text('Cult Fitness Hub'));
    await tester.pump();
    expect(opened?.id, 'c1');
  });

  testWidgets('See all member route is Discover centers', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openHomeCentersSeeAll(context, isProvider: false),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, state) => Text(
            'centers-list ${state.uri.queryParameters['discover']} tab=${state.uri.queryParameters['tab']}',
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('centers-list centers tab=1'), findsOneWidget);
  });

  testWidgets('empty real center list hides the section', (tester) async {
    await _pumpPreview(tester, centers: const []);
    expect(find.text('Centers'), findsNothing);
    expect(find.text('Power Gym'), findsNothing);
    expect(find.text('No centers available yet'), findsNothing);
  });

  testWidgets('no stock fallback image on center row', (tester) async {
    await _pumpPreview(
      tester,
      centers: [_center(id: 'c1', name: 'Cult Fitness Hub')],
    );
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.apartment_rounded), findsWidgets);
  });

  testWidgets('centers preview light, dark, small screen, large text',
      (tester) async {
    final centers = [_center(id: 'c1', name: 'Very Long Wellness Center Name')];
    await _pumpPreview(
      tester,
      centers: centers,
      theme: AppTheme.lightTheme,
      size: const Size(320, 640),
      textScale: 1.5,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Very Long Wellness'), findsOneWidget);

    await _pumpPreview(
      tester,
      centers: centers,
      theme: AppTheme.darkTheme,
      size: const Size(320, 640),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('user with no cover does not request Unsplash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: HeroHeaderV3(
            username: 'Ada',
            coverImageUrl: null,
            streakDays: 1,
            notificationCount: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) {
        return w is CachedNetworkImage &&
            w.imageUrl.toLowerCase().contains('unsplash');
      }),
      findsNothing,
    );
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('goal loading shows skeleton not default 10000 target',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedMetricsTileV3(
            goalsLoading: true,
            metrics: _dummyMetrics(),
            onMetricTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('10000'), findsNothing);
    expect(find.text('of 10000 steps'), findsNothing);
  });

  testWidgets('Member Explore uses client tiles and copy', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _exploreOverrides(_user('client')),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(child: QuickAccessV3()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trainers & Nutritionists'), findsOneWidget);
    expect(find.text('Member Pass'), findsOneWidget);
    expect(find.text('Subscription'), findsNothing);
    expect(find.text('Join live sessions with your trainer.'), findsOneWidget);
    expect(find.text('Clients'), findsNothing);
  });

  testWidgets('Trainer Explore uses provider copy and hides member tiles',
      (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _exploreOverrides(_user('trainer')),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(child: QuickAccessV3()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trainers & Nutritionists'), findsNothing);
    expect(find.text('Subscription'), findsNothing);
    expect(find.text('Member Pass'), findsNothing);
    expect(find.text('Schedule and manage video sessions'), findsOneWidget);
    expect(find.text('Join live sessions with your trainer.'), findsNothing);
  });

  testWidgets('Nutritionist Explore uses provider copy and hides member tiles',
      (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _exploreOverrides(_user('nutritionist')),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(child: QuickAccessV3()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trainers & Nutritionists'), findsNothing);
    expect(find.text('Subscription'), findsNothing);
    expect(find.text('Member Pass'), findsNothing);
    expect(find.text('Schedule and manage video sessions'), findsOneWidget);
  });

  testWidgets('provider loading does not display fake Trainer name',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HeroHeaderV3(
            username: '',
            usernameLoading: true,
            streakDays: 0,
            notificationCount: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Trainer'), findsNothing);
    expect(find.text('Nutritionist'), findsNothing);
  });
}
