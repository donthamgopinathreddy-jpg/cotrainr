import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cotrainr/pages/client_monitoring/client_coach_notes_page.dart';
import 'package:cotrainr/pages/client_monitoring/client_detail_shell.dart';
import 'package:cotrainr/pages/client_monitoring/client_meals_panel.dart';
import 'package:cotrainr/pages/nutritionist/nutritionist_client_detail_page.dart';
import 'package:cotrainr/pages/trainer/client_detail_page.dart';
import 'package:cotrainr/pages/trainer/create_client_page.dart';
import 'package:cotrainr/repositories/coach_notes_repository.dart';
import 'package:cotrainr/repositories/meal_repository.dart';
import 'package:cotrainr/repositories/video_sessions_repository.dart';
import 'package:cotrainr/services/coach_client_access_service.dart';
import 'package:cotrainr/theme/app_theme.dart';

const _clientId = 'client-1';

CoachClientAccessStatus _trainerAccess({
  bool metrics = false,
  bool meals = false,
  bool accepted = true,
}) {
  return CoachClientAccessStatus(
    hasAcceptedLead: accepted,
    providerType: 'trainer',
    shareMetricsWithTrainer: metrics,
    shareMealsWithTrainer: meals,
  );
}

CoachClientAccessStatus _nutritionistAccess({
  bool meals = false,
  bool accepted = true,
}) {
  return CoachClientAccessStatus(
    hasAcceptedLead: accepted,
    providerType: 'nutritionist',
    shareNutritionWithNutritionist: meals,
  );
}

Map<String, dynamic> _profile({
  String name = 'Gopinath Reddy',
  String username = 'don_5412',
  String? avatar,
}) {
  return {
    'full_name': name,
    'username': username,
    'avatar_url': avatar,
  };
}

DayMealsData _meals() {
  return const DayMealsData(
    mealsByType: {
      'breakfast': [
        MealItemRow(
          id: 'b1',
          foodName: 'Oats',
          quantity: 1,
          unit: 'bowl',
          calories: 320,
          protein: 12,
          carbs: 50,
          fat: 6,
          fiber: 8,
        ),
      ],
      'lunch': [
        MealItemRow(
          id: 'l1',
          foodName: 'Chicken salad',
          quantity: 1,
          unit: 'plate',
          calories: 520,
          protein: 42,
          carbs: 18,
          fat: 22,
          fiber: 6,
        ),
      ],
    },
    totalCalories: 1820,
    totalProtein: 126,
    totalCarbs: 180,
    totalFats: 55,
    totalFiber: 22,
  );
}

Map<String, dynamic> _metrics() {
  return {
    'steps': 8214,
    'calories_burned': 1823,
    'distance_km': 5.4,
    'water_intake_liters': 1.5,
  };
}

VideoSession _session() {
  return VideoSession(
    id: 'sess-1',
    hostId: 'coach-1',
    provider: 'google_meet',
    title: 'Strength Coaching',
    scheduledStart: DateTime.now().add(const Duration(hours: 3)),
    durationMinutes: 30,
    maxParticipants: 5,
    status: 'scheduled',
    joinUrl: 'https://meet.google.com/abc',
    createdAt: DateTime.now(),
    clientId: _clientId,
  );
}

CoachNote _note({
  required String id,
  required String content,
  required DateTime createdAt,
  String clientId = _clientId,
  String coachId = 'coach-1',
}) {
  return CoachNote(
    id: id,
    coachId: coachId,
    clientId: clientId,
    content: content,
    createdAt: createdAt,
  );
}

class _FakeNotes implements CoachNotesApi {
  _FakeNotes({
    List<CoachNote>? notes,
    this.loadError = false,
    this.loadDelay = Duration.zero,
  }) : notes = notes ?? [];

  List<CoachNote> notes;
  final bool loadError;
  final Duration loadDelay;
  String? lastClientId;
  String? lastAddedContent;
  String? lastDeletedId;

  @override
  Future<List<CoachNote>> getNotesForClient(String clientId) async {
    lastClientId = clientId;
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    if (loadError) throw Exception('network');
    return List.of(notes);
  }

  @override
  Future<CoachNote?> addNote(String clientId, String content) async {
    lastClientId = clientId;
    lastAddedContent = content;
    final note = CoachNote(
      id: 'new-${notes.length}',
      coachId: 'coach-1',
      clientId: clientId,
      content: content,
      createdAt: DateTime.now(),
    );
    notes.insert(0, note);
    return note;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    lastDeletedId = noteId;
    notes.removeWhere((n) => n.id == noteId);
  }
}

Future<void> _pumpRouted(
  WidgetTester tester, {
  required Widget home,
  ThemeData? theme,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      GoRoute(
        path: '/video',
        builder: (_, state) => Scaffold(
          body: Text('video:${state.uri.query}'),
        ),
      ),
      GoRoute(
        path: '/video/session/:id',
        builder: (_, state) => Scaffold(
          body: Text('session:${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/messaging/chat/:id',
        builder: (_, state) => Scaffold(
          body: Text('chat:${state.pathParameters['id']}'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      theme: theme ?? AppTheme.lightTheme,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

ClientDetailShell _trainerShell({
  CoachClientAccessStatus? access,
  Map<String, dynamic>? profile,
  Map<String, dynamic>? metrics,
  DayMealsData? meals,
  List<CoachNote> notes = const [],
  VideoSession? upcoming,
  ClientItem? initialClient,
  CoachNotesApi? notesApi,
  String clientId = _clientId,
}) {
  final resolvedAccess = access ?? _trainerAccess();
  final resolvedNotes = notes;
  return ClientDetailShell(
    clientId: clientId,
    initialClient: initialClient,
    isNutritionist: false,
    notesRepository: notesApi,
    loadAccess: (_) async => resolvedAccess,
    loadProfile: (_) async => profile ?? _profile(),
    loadMetrics: (_) async => metrics,
    loadMeals: (_) async => meals ?? DayMealsData.empty(),
    loadNotes: (_) async => List<CoachNote>.from(resolvedNotes),
    loadUpcoming: (_) async => upcoming,
  );
}

ClientDetailShell _nutritionistShell({
  CoachClientAccessStatus? access,
  Map<String, dynamic>? profile,
  DayMealsData? meals,
  List<CoachNote> notes = const [],
  VideoSession? upcoming,
  CoachNotesApi? notesApi,
  String clientId = _clientId,
}) {
  final resolvedAccess = access ?? _nutritionistAccess();
  return ClientDetailShell(
    clientId: clientId,
    isNutritionist: true,
    notesRepository: notesApi,
    loadAccess: (_) async => resolvedAccess,
    loadProfile: (_) async => profile ?? _profile(),
    loadMeals: (_) async => meals ?? DayMealsData.empty(),
    loadNotes: (_) async => notes,
    loadUpcoming: (_) async => upcoming,
  );
}

void _expectNoFakeMonitoringCopy() {
  expect(find.text('Weekly Summary'), findsNothing);
  expect(find.textContaining('85.5'), findsNothing);
  expect(find.textContaining('8.2k'), findsNothing);
  expect(find.textContaining('1.8k'), findsNothing);
  expect(find.text('Water Low'), findsNothing);
  expect(find.text('Protein Low'), findsNothing);
  expect(find.text('Weight Spike'), findsNothing);
  expect(find.text('Overtraining'), findsNothing);
  expect(find.text('Missed Check-in'), findsNothing);
  expect(find.text('Export PDF'), findsNothing);
  expect(find.text('Send Reminder'), findsNothing);
  expect(find.textContaining('Last check-in'), findsNothing);
  expect(find.text('Trend Charts'), findsNothing);
  expect(find.text('Reports'), findsNothing);
  expect(find.text('Assign Plan'), findsNothing);
  expect(find.text('Workouts'), findsNothing);
  expect(find.text('Metrics'), findsNothing);
  expect(find.text('Sessions'), findsNothing);
  expect(find.text('John Doe'), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trainer client detail', () {
    testWidgets('renders real profile and hides mock monitoring', (tester) async {
      await _pumpRouted(
        tester,
        home: _trainerShell(
          access: _trainerAccess(metrics: true, meals: true),
          metrics: _metrics(),
          meals: _meals(),
          notes: [
            _note(
              id: 'n1',
              content: 'Focus on squat depth next session.',
              createdAt: DateTime(2026, 8, 18),
            ),
          ],
          upcoming: _session(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gopinath Reddy'), findsWidgets);
      expect(find.text('@don_5412'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Video Session'), findsOneWidget);
      expect(find.text('Client Notes'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Meals'), findsOneWidget);
      expect(find.text('Activity today'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('8,214').evaluate().isNotEmpty || find.text('8214').evaluate().isNotEmpty, isTrue);
      expect(find.text('1823 kcal'), findsOneWidget);
      expect(find.text('5.4 km'), findsOneWidget);
      expect(find.text('1.5 L'), findsOneWidget);
      expect(find.text('Meals today'), findsOneWidget);
      expect(find.text('2 logged'), findsOneWidget);
      expect(find.textContaining('1820 kcal'), findsOneWidget);
      expect(find.text('Latest coach note'), findsOneWidget);
      expect(find.text('Focus on squat depth next session.'), findsOneWidget);
      expect(find.text('Upcoming session'), findsOneWidget);
      expect(find.text('Strength Coaching'), findsOneWidget);
      _expectNoFakeMonitoringCopy();
    });

    testWidgets('does not fall back to John Doe when extras are fake or missing',
        (tester) async {
      await _pumpRouted(
        tester,
        home: _trainerShell(
          initialClient: ClientItem(
            id: _clientId,
            name: 'John Doe',
            email: 'john@example.com',
            phone: '',
            joinDate: DateTime(2026, 1, 1),
            status: ClientStatus.active,
          ),
          profile: _profile(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsNothing);
      expect(find.text('Gopinath Reddy'), findsWidgets);
    });

    testWidgets('shows not-found instead of a fake identity', (tester) async {
      await _pumpRouted(
        tester,
        home: ClientDetailShell(
          clientId: _clientId,
          loadAccess: (_) async => _trainerAccess(),
          loadProfile: (_) async => null,
          loadNotes: (_) async => const [],
          loadUpcoming: (_) async => null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Client not found'), findsOneWidget);
      expect(find.text('John Doe'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('metrics permission off is not shown as zeros', (tester) async {
      await _pumpRouted(
        tester,
        home: _trainerShell(
          access: _trainerAccess(metrics: false, meals: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Activity sharing is off'), findsOneWidget);
      expect(find.text('Steps'), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.text('Meal sharing is off'), findsWidgets);
    });

    testWidgets('metrics permission on uses real values and dashes for missing',
        (tester) async {
      await _pumpRouted(
        tester,
        home: _trainerShell(
          access: _trainerAccess(metrics: true),
          metrics: const {
            'steps': 8214,
            'calories_burned': null,
            'distance_km': null,
            'water_intake_liters': 1.5,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8,214').evaluate().isNotEmpty || find.text('8214').evaluate().isNotEmpty, isTrue);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('1.5 L'), findsOneWidget);
      expect(find.text('10,000'), findsNothing);
      expect(find.text('2.5 L'), findsNothing);
    });

    testWidgets('meal permission on/off', (tester) async {
      await _pumpRouted(
        tester,
        home: _trainerShell(
          access: _trainerAccess(meals: true),
          meals: _meals(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 logged'), findsOneWidget);
      expect(find.text('Meal sharing is off'), findsNothing);

      await tester.tap(find.text('Meals'));
      await tester.pumpAndSettle();
      expect(find.text('Oats'), findsOneWidget);
      expect(find.text('Chicken salad'), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
    });

    testWidgets('Client Notes action opens per-client page', (tester) async {
      final notes = _FakeNotes(
        notes: [
          _note(
            id: 'n1',
            content: 'Focus on squat depth next session.',
            createdAt: DateTime(2026, 8, 18),
          ),
        ],
      );
      await _pumpRouted(
        tester,
        home: _trainerShell(notesApi: notes, notes: notes.notes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Client Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Client Notes'), findsWidgets);
      expect(find.text('Gopinath Reddy'), findsWidgets);
      expect(
        find.text('Notes you add here are visible to the client.'),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);
      expect(find.text('Focus on squat depth next session.'), findsOneWidget);
    });

    testWidgets('Video Session action opens existing video flow', (tester) async {
      await _pumpRouted(tester, home: _trainerShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Video Session'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('video:openCreate=1'),
        findsOneWidget,
      );
      expect(find.textContaining('clientId=client-1'), findsOneWidget);
    });

    testWidgets('upcoming session View opens session detail', (tester) async {
      await _pumpRouted(
        tester,
        home: _trainerShell(upcoming: _session()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('session:sess-1'), findsOneWidget);
    });
  });

  group('Nutritionist client detail', () {
    testWidgets('requires an accepted relationship', (tester) async {
      await _pumpRouted(
        tester,
        home: _nutritionistShell(
          access: _nutritionistAccess(accepted: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This client is not connected.'), findsOneWidget);
      expect(find.text('Activity today'), findsNothing);
      expect(find.text('John Doe'), findsNothing);
    });

    testWidgets('has no fake vitals or trainer metrics', (tester) async {
      await _pumpRouted(
        tester,
        home: _nutritionistShell(
          access: _nutritionistAccess(meals: true),
          meals: _meals(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gopinath Reddy'), findsWidgets);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Meals'), findsOneWidget);
      expect(find.text('Workouts'), findsNothing);
      expect(find.text('Activity today'), findsNothing);
      expect(find.text('Steps'), findsNothing);
      expect(find.textContaining('28'), findsNothing);
      expect(find.textContaining('175'), findsNothing);
      expect(find.text('Diet Plans'), findsNothing);
      expect(find.textContaining('kg'), findsNothing);
      _expectNoFakeMonitoringCopy();
    });

    testWidgets('meal permission off vs macros when on', (tester) async {
      await _pumpRouted(
        tester,
        home: _nutritionistShell(
          access: _nutritionistAccess(meals: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Meal sharing is off'), findsWidgets);

      await _pumpRouted(
        tester,
        home: _nutritionistShell(
          access: _nutritionistAccess(meals: true),
          meals: _meals(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('P 126g'), findsOneWidget);
      expect(find.textContaining('C 180g'), findsOneWidget);
      expect(find.textContaining('F 55g'), findsOneWidget);
      expect(find.textContaining('Fi 22g'), findsOneWidget);

      await tester.tap(find.text('Meals'));
      await tester.pumpAndSettle();
      expect(find.text('Calories'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('Fiber'), findsOneWidget);
      expect(find.text('Oats'), findsOneWidget);
    });

    testWidgets('Client Notes navigation stays client-visible', (tester) async {
      final notes = _FakeNotes();
      await _pumpRouted(
        tester,
        home: _nutritionistShell(notesApi: notes),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Client Notes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Notes you add here are visible to the client.'),
        findsOneWidget,
      );
    });

    testWidgets('wrapper pages do not invent a client identity', (tester) async {
      await _pumpRouted(
        tester,
        home: const NutritionistClientDetailPage(clientId: ''),
      );
      await tester.pumpAndSettle();
      expect(find.text('Client not found'), findsOneWidget);

      await _pumpRouted(
        tester,
        home: const ClientDetailPage(clientId: ''),
      );
      await tester.pumpAndSettle();
      expect(find.text('Client not found'), findsOneWidget);
      expect(find.text('John Doe'), findsNothing);
    });
  });

  group('Client Notes page', () {
    testWidgets('shows client-visible wording, empty/loading/error, newest first',
        (tester) async {
      final loading = _FakeNotes(loadDelay: const Duration(milliseconds: 300));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ClientCoachNotesPage(
            clientId: _clientId,
            clientName: 'Gopinath Reddy',
            notesRepository: loading,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('No notes yet'), findsOneWidget);
      expect(
        find.text('Notes you add here are visible to the client.'),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);
    });

    testWidgets('shows an error state when notes fail to load', (tester) async {
      final failing = _FakeNotes(loadError: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ClientCoachNotesPage(
            clientId: _clientId,
            clientName: 'Gopinath Reddy',
            notesRepository: failing,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Could not load notes'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('lists notes newest first', (tester) async {
      final ordered = _FakeNotes(
        notes: [
          _note(
            id: 'old',
            content: 'Older note',
            createdAt: DateTime(2026, 8, 17),
          ),
          _note(
            id: 'new',
            content: 'Newer note',
            createdAt: DateTime(2026, 8, 18),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ClientCoachNotesPage(
            clientId: _clientId,
            clientName: 'Gopinath Reddy',
            notesRepository: ordered,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final newer = tester.getTopLeft(find.text('Newer note'));
      final older = tester.getTopLeft(find.text('Older note'));
      expect(newer.dy, lessThan(older.dy));
    });

    testWidgets('create and delete notes for the opened client', (tester) async {
      final notes = _FakeNotes();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ClientCoachNotesPage(
            clientId: _clientId,
            clientName: 'Gopinath Reddy',
            notesRepository: notes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Increase vegetables with lunch this week.',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(notes.lastClientId, _clientId);
      expect(notes.lastAddedContent, 'Increase vegetables with lunch this week.');
      expect(
        find.text('Increase vegetables with lunch this week.'),
        findsOneWidget,
      );

      expect(find.byTooltip('Delete note'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete note'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this note?'), findsOneWidget);
      expect(
        find.text('The client will no longer see this note.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(notes.lastDeletedId, 'new-0');
      expect(
        find.text('Increase vegetables with lunch this week.'),
        findsNothing,
      );
    });
  });

  group('Themes and layout', () {
    testWidgets('light and dark themes render without overflow', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await _pumpRouted(
          tester,
          theme: theme,
          home: _trainerShell(
            access: _trainerAccess(metrics: true, meals: true),
            metrics: _metrics(),
            meals: _meals(),
            notes: [
              _note(
                id: 'n1',
                content: 'Good progress this week — maintain the current plan.',
                createdAt: DateTime(2026, 8, 17),
              ),
            ],
            upcoming: _session(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Gopinath Reddy'), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('small screen and text scaling do not clip actions',
        (tester) async {
      await _pumpRouted(
        tester,
        size: const Size(320, 568),
        textScale: 1.3,
        home: _trainerShell(
          access: _trainerAccess(metrics: true, meals: true),
          metrics: _metrics(),
          meals: _meals(),
          profile: _profile(
            name: 'Gopinath Venkata Reddy',
            username: 'very_long_username_5412',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Video Session'), findsOneWidget);
      expect(find.text('Client Notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('meals panel lists foods and trainer vs nutritionist macros',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: ClientMealsPanel(meals: _meals())),
      ),
    );
    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Carbs'), findsNothing);
    expect(find.text('Oats'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ClientMealsPanel(meals: _meals(), richMacros: true),
        ),
      ),
    );
    expect(find.text('Carbs'), findsOneWidget);
    expect(find.text('Fat'), findsOneWidget);
    expect(find.text('Fiber'), findsOneWidget);
  });
}
