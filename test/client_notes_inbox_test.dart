import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/pages/coach_notes/coach_notes_page.dart';
import 'package:cotrainr/pages/coach_notes/provider_notes_detail_page.dart';
import 'package:cotrainr/repositories/coach_notes_repository.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/utils/client_notes_grouping.dart';
import 'package:cotrainr/widgets/video_sessions/video_session_avatar.dart';

CoachNote _note({
  required String id,
  required String coachId,
  required String clientId,
  required String content,
  required DateTime createdAt,
  String? name,
  String? avatar,
  String type = '',
}) {
  return CoachNote(
    id: id,
    coachId: coachId,
    clientId: clientId,
    content: content,
    createdAt: createdAt,
    coachName: name,
    coachAvatarUrl: avatar,
    coachType: type,
  );
}

class _FakeInbox implements CoachNotesInboxApi {
  _FakeInbox({
    this.notes = const [],
    this.error,
    this.delay,
  });

  final List<CoachNote> notes;
  final Object? error;
  final Duration? delay;

  @override
  Future<List<CoachNote>> getMyNotes() async {
    if (delay != null) await Future<void>.delayed(delay!);
    if (error != null) throw error!;
    return notes;
  }
}

Future<void> _pumpInbox(
  WidgetTester tester, {
  required ThemeData theme,
  required CoachNotesInboxApi inbox,
  String viewerClientId = 'client-x',
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: CoachNotesPage(
        inbox: inbox,
        viewerClientId: viewerClientId,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final trainerA = _note(
    id: 'n1',
    coachId: 'trainer-a',
    clientId: 'client-x',
    content: 'Focus on squat depth this week.',
    createdAt: DateTime(2026, 8, 18),
    name: 'Arjun Kumar',
    avatar: 'https://example.com/arjun.png',
    type: 'trainer',
  );
  final trainerAOlder = _note(
    id: 'n0',
    coachId: 'trainer-a',
    clientId: 'client-x',
    content: 'Keep rest periods around 90 seconds.',
    createdAt: DateTime(2026, 8, 10),
    name: 'Arjun Kumar',
    avatar: 'https://example.com/arjun.png',
    type: 'trainer',
  );
  final trainerAMid = _note(
    id: 'n2',
    coachId: 'trainer-a',
    clientId: 'client-x',
    content: 'Good progress. Keep your current training consistency.',
    createdAt: DateTime(2026, 8, 15),
    name: 'Arjun Kumar',
    type: 'trainer',
  );
  final nutritionistB = _note(
    id: 'n3',
    coachId: 'nutri-b',
    clientId: 'client-x',
    content: 'Increase vegetables at lunch.',
    createdAt: DateTime(2026, 8, 17),
    name: 'Priya Sharma',
    type: 'nutritionist',
  );
  final trainerC = _note(
    id: 'n4',
    coachId: 'trainer-c',
    clientId: 'client-x',
    content: 'Add a second easy run.',
    createdAt: DateTime(2026, 8, 10),
    name: 'Rahul Singh',
    type: 'trainer',
  );
  final nutritionistD = _note(
    id: 'n5',
    coachId: 'nutri-d',
    clientId: 'client-x',
    content: 'Keep protein even across meals.',
    createdAt: DateTime(2026, 8, 9),
    name: 'Meera Iyer',
    type: 'nutritionist',
  );
  final otherClient = _note(
    id: 'ny',
    coachId: 'trainer-a',
    clientId: 'client-y',
    content: 'Secret note for someone else.',
    createdAt: DateTime(2026, 8, 19),
    name: 'Arjun Kumar',
    type: 'trainer',
  );

  group('groupClientNotesByProvider', () {
    test('groups trainers and nutritionists separately and sorts by latest', () {
      final groups = groupClientNotesByProvider([
        trainerAOlder,
        nutritionistB,
        trainerA,
        trainerC,
        nutritionistD,
        trainerAMid,
      ]);

      expect(groups.map((g) => g.providerId).toList(), [
        'trainer-a',
        'nutri-b',
        'trainer-c',
        'nutri-d',
      ]);
      expect(groups[0].name, 'Arjun Kumar');
      expect(groups[0].roleLabel, 'Trainer');
      expect(groups[0].noteCount, 3);
      expect(groups[0].notes.first.content, 'Focus on squat depth this week.');
      expect(groups[1].name, 'Priya Sharma');
      expect(groups[1].roleLabel, 'Nutritionist');
      expect(groups[2].roleLabel, 'Trainer');
      expect(groups[3].roleLabel, 'Nutritionist');
    });

    test('hides another client\'s notes when a viewer id is provided', () {
      final groups = groupClientNotesByProvider(
        [trainerA, otherClient, nutritionistB],
        viewerClientId: 'client-x',
      );
      expect(groups, hasLength(2));
      expect(
        groups.expand((g) => g.notes).map((n) => n.content),
        isNot(contains('Secret note for someone else.')),
      );
    });

    test('does not invent Coach/Unknown labels', () {
      expect(providerRoleLabel('trainer'), 'Trainer');
      expect(providerRoleLabel('nutritionist'), 'Nutritionist');
      expect(providerRoleLabel('client'), isNull);
      expect(providerRoleLabel(null), isNull);
      expect(providerRoleLabel(''), isNull);
    });
  });

  group('Explore copy', () {
    test('client Explore card is Notes, not Coach Notes', () {
      expect(kClientNotesExploreTitle, 'Notes');
      expect(
        kClientNotesExploreSubtitle,
        'Feedback from your trainers & nutritionists',
      );
      expect(kClientNotesScreenTitle, 'Notes');
    });
  });

  group('CoachNotesPage', () {
    testWidgets('shows trainer and nutritionist notes grouped by provider',
        (tester) async {
      await _pumpInbox(
        tester,
        theme: AppTheme.lightTheme,
        inbox: _FakeInbox(
          notes: [
            trainerA,
            trainerAMid,
            trainerAOlder,
            nutritionistB,
            trainerC,
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsWidgets);
      expect(find.text('Coach Notes'), findsNothing);
      expect(find.text('Coaches'), findsNothing);
      expect(find.text('Nutritionist'), findsOneWidget);
      expect(find.text('Arjun Kumar'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Rahul Singh'), findsOneWidget);
      expect(find.text('Trainer'), findsNWidgets(2));
      expect(find.textContaining('3 notes'), findsOneWidget);
      expect(find.textContaining('Latest 18 Aug'), findsOneWidget);
      expect(find.byType(VideoSessionAvatar), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Send'), findsNothing);
    });

    testWidgets('opens provider notes newest first without a composer',
        (tester) async {
      await _pumpInbox(
        tester,
        theme: AppTheme.lightTheme,
        inbox: _FakeInbox(notes: [trainerA, trainerAOlder, trainerAMid]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arjun Kumar'));
      await tester.pumpAndSettle();

      expect(find.byType(ProviderNotesDetailPage), findsOneWidget);
      expect(find.text('Arjun Kumar'), findsWidgets);
      expect(find.text('Trainer'), findsWidgets);
      expect(find.text('18 Aug 2026'), findsOneWidget);
      expect(find.text('15 Aug 2026'), findsOneWidget);
      expect(find.text('10 Aug 2026'), findsOneWidget);
      expect(find.text('Focus on squat depth this week.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Note for'), findsNothing);

      final dates = tester.widgetList<Text>(find.textContaining('Aug 2026'));
      expect(dates.first.data, '18 Aug 2026');
    });

    testWidgets('uses initial fallback when avatar is missing', (tester) async {
      await _pumpInbox(
        tester,
        theme: AppTheme.darkTheme,
        inbox: _FakeInbox(
          notes: [
            _note(
              id: 'n6',
              coachId: 't-no-photo',
              clientId: 'client-x',
              content: 'No photo here.',
              createdAt: DateTime(2026, 8, 12),
              name: 'No Photo',
              type: 'trainer',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('N'), findsWidgets);
      expect(find.byType(VideoSessionAvatar), findsOneWidget);
    });

    testWidgets('query error shows error state, not empty state', (tester) async {
      await _pumpInbox(
        tester,
        theme: AppTheme.lightTheme,
        inbox: _FakeInbox(error: const CoachNotesLoadException('query_failed')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Couldn\'t load notes'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No notes yet'), findsNothing);
    });

    testWidgets('empty inbox shows empty copy', (tester) async {
      await _pumpInbox(
        tester,
        theme: AppTheme.darkTheme,
        inbox: _FakeInbox(notes: const []),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notes yet'), findsOneWidget);
      expect(
        find.text(
          'Feedback from your trainers and nutritionists will appear here.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('dashboard'), findsNothing);
      expect(find.text('Couldn\'t load notes'), findsNothing);
    });

    testWidgets('does not show another client\'s notes', (tester) async {
      await _pumpInbox(
        tester,
        theme: AppTheme.lightTheme,
        inbox: _FakeInbox(notes: [trainerA, otherClient]),
        viewerClientId: 'client-x',
      );
      await tester.pumpAndSettle();
      expect(find.text('Secret note for someone else.'), findsNothing);
      await tester.tap(find.text('Arjun Kumar'));
      await tester.pumpAndSettle();
      expect(find.text('Secret note for someone else.'), findsNothing);
      expect(find.text('Focus on squat depth this week.'), findsOneWidget);
    });

    testWidgets('All notes is chronological and not the default', (tester) async {
      await _pumpInbox(
        tester,
        theme: AppTheme.lightTheme,
        inbox: _FakeInbox(notes: [trainerA, nutritionistB]),
      );
      await tester.pumpAndSettle();
      expect(find.text('All notes'), findsOneWidget);
      expect(find.text('Increase vegetables at lunch.'), findsNothing);

      await tester.tap(find.text('All notes'));
      await tester.pumpAndSettle();
      expect(find.text('Focus on squat depth this week.'), findsOneWidget);
      expect(find.text('Increase vegetables at lunch.'), findsOneWidget);
      expect(find.textContaining('Arjun Kumar · Trainer'), findsOneWidget);
      expect(find.textContaining('Priya Sharma · Nutritionist'), findsOneWidget);
    });

    testWidgets('light and dark themes render without overflow', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await _pumpInbox(
          tester,
          theme: theme,
          size: const Size(320, 568),
          inbox: _FakeInbox(
            notes: [
              trainerA,
              nutritionistB,
              _note(
                id: 'long',
                coachId: 'long-id',
                clientId: 'client-x',
                content: 'Keep going.',
                createdAt: DateTime(2026, 8, 1),
                name: 'Gopinath Venkata Reddy',
                type: 'trainer',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Notes'), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('shows a row skeleton while loading', (tester) async {
      await _pumpInbox(
        tester,
        theme: AppTheme.lightTheme,
        inbox: _FakeInbox(
          delay: const Duration(milliseconds: 200),
          notes: [trainerA],
        ),
      );
      await tester.pump();
      expect(find.text('Arjun Kumar'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Arjun Kumar'), findsOneWidget);
    });
  });
}
