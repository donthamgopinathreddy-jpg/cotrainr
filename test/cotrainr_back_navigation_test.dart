import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/widgets/common/cotrainr_back_button.dart';

Widget _page(String title) {
  return Scaffold(
    body: Center(child: Text(title)),
  );
}

GoRouter _router({
  String initial = '/video',
  List<NavigatorObserver>? observers,
}) {
  return GoRouter(
    initialLocation: initial,
    observers: observers,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => _page('Home'),
      ),
      GoRoute(
        path: '/video',
        builder: (_, __) => Scaffold(
          appBar: const CotrainrAppBar(
            title: 'Video Sessions',
            fallbackRoute: '/home',
          ),
          body: const Center(child: Text('Upcoming list')),
        ),
      ),
      GoRoute(
        path: '/video/session/:id',
        builder: (context, state) => CotrainrPopScope(
          fallbackRoute: '/video',
          child: Scaffold(
            appBar: const CotrainrAppBar(
              title: 'Session',
              fallbackRoute: '/video',
            ),
            body: const Center(child: Text('Session detail')),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => Scaffold(
          appBar: const CotrainrAppBar(title: 'Settings'),
          body: const Center(child: Text('Settings')),
        ),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (_, __) => Scaffold(
          appBar: const CotrainrAppBar(title: 'Client'),
          body: const Center(child: Text('Client detail')),
        ),
      ),
    ],
  );
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  ThemeData? theme,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: theme ?? AppTheme.lightTheme,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CotrainrBackButton', () {
    testWidgets('uses chevron_left_rounded and a 48dp tap target',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: const CotrainrBackButton(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.constraints?.minWidth, greaterThanOrEqualTo(44));
      expect(button.constraints?.minHeight, greaterThanOrEqualTo(44));

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('pops when history exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          appBar: CotrainrAppBar(title: 'Child'),
                          body: Text('Child page'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Child page'), findsOneWidget);

      await tester.tap(find.byType(CotrainrBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Child page'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('falls back when there is no history', (tester) async {
      final router = _router(initial: '/video/session/abc');
      await _pumpRouter(tester, router);

      expect(find.text('Session detail'), findsOneWidget);
      await tester.tap(find.byType(CotrainrBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Upcoming list'), findsOneWidget);
    });

    testWidgets('light and dark both render the chevron', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              appBar: CotrainrAppBar(title: 'Session'),
            ),
          ),
        );
        expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
        expect(find.bySemanticsLabel('Back'), findsWidgets);
      }
    });
  });

  group('Session detail navigation', () {
    testWidgets('Upcoming list → Session Detail → Back', (tester) async {
      final router = _router();
      await _pumpRouter(tester, router);
      expect(find.text('Upcoming list'), findsOneWidget);

      router.push('/video/session/s1');
      await tester.pumpAndSettle();
      expect(find.text('Session detail'), findsOneWidget);

      await tester.tap(find.byType(CotrainrBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Upcoming list'), findsOneWidget);
      expect(find.text('Session detail'), findsNothing);
    });

    testWidgets('Past Sessions → Session Detail → Back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              appBar: const CotrainrAppBar(title: 'Past Sessions'),
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          appBar: CotrainrAppBar(
                            title: 'Session',
                            fallbackRoute: '/video',
                          ),
                          body: Text('Session detail'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open past session'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open past session'));
      await tester.pumpAndSettle();
      expect(find.text('Session detail'), findsOneWidget);

      await tester.tap(find.byType(CotrainrBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Past Sessions'), findsOneWidget);
      expect(find.text('Open past session'), findsOneWidget);
    });

    testWidgets('session becoming past does not trap back', (tester) async {
      var ended = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (outer) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(outer).push(
                      MaterialPageRoute<void>(
                        builder: (_) {
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return CotrainrPopScope(
                                fallbackRoute: '/video',
                                child: Scaffold(
                                  appBar: const CotrainrAppBar(
                                    title: 'Session',
                                    fallbackRoute: '/video',
                                  ),
                                  body: Column(
                                    children: [
                                      Text(ended ? 'Completed' : 'Upcoming'),
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => ended = true),
                                        child: const Text('End session'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End session'));
      await tester.pump();
      expect(find.text('Completed'), findsOneWidget);

      await tester.tap(find.byType(CotrainrBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('direct session route with no history falls back to Video Sessions',
        (tester) async {
      final router = _router(initial: '/video/session/s1');
      await _pumpRouter(tester, router);
      expect(find.text('Session detail'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      expect(find.text('Upcoming list'), findsOneWidget);
    });

    testWidgets('system pop with no history uses fallback', (tester) async {
      final router = _router(initial: '/video/session/s1');
      await _pumpRouter(tester, router);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Upcoming list'), findsOneWidget);
    });
  });

  group('Settings and Client detail', () {
    testWidgets('Settings child returns to previous page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          appBar: CotrainrAppBar(title: 'Settings'),
                          body: Text('Settings body'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings body'), findsOneWidget);
      await tester.tap(find.byType(CotrainrBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('Client detail returns to previous page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          appBar: CotrainrAppBar(title: 'Client'),
                          body: Text('Client detail'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open client'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open client'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CotrainrBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open client'), findsOneWidget);
    });
  });

  group('Root destinations', () {
    testWidgets('HomeShell has no CotrainrBackButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Text('Home'),
            bottomNavigationBar: SizedBox(height: 64, child: Text('nav')),
          ),
        ),
      );
      expect(find.byType(CotrainrBackButton), findsNothing);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    });
  });
}
