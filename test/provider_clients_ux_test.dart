import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/pages/provider/provider_my_clients_page.dart';
import 'package:cotrainr/pages/trainer/create_client_page.dart';
import 'package:cotrainr/providers/provider_practice_provider.dart';
import 'package:cotrainr/repositories/video_sessions_repository.dart';
import 'package:cotrainr/services/leads_models.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/widgets/home_v3/home_premium_theme.dart';
import 'package:cotrainr/widgets/provider/provider_clients_summary.dart';
import 'package:cotrainr/widgets/video_sessions/video_session_avatar.dart';

Finder _redAttentionDots() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    return decoration.color == DesignTokens.accentRed &&
        decoration.shape == BoxShape.circle;
  });
}

ClientItem _client({
  required String id,
  required String name,
  ClientStatus status = ClientStatus.active,
  String? leadId,
  String? requestMessage,
  String? avatar,
  String email = 'Active',
}) {
  return ClientItem(
    id: id,
    name: name,
    email: email,
    phone: '',
    joinDate: DateTime(2026, 8, 18),
    status: status,
    avatar: avatar,
    leadId: leadId,
    requestMessage: requestMessage,
  );
}

Finder _tintedSurfaces(Color color) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    return decoration.color == color && decoration.border == null;
  });
}

Future<void> _pumpSummary(
  WidgetTester tester, {
  required ThemeData theme,
  Size size = const Size(390, 844),
  double textScale = 1,
  int activeCount = 2,
  int requestCount = 1,
  List<ProviderClientPreview> clients = const [],
  ProviderNextSessionPreview? nextSession,
  VoidCallback? onOpenClients,
  VoidCallback? onOpenRequests,
  VoidCallback? onOpenNotes,
  VoidCallback? onOpenNextSession,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: ProviderClientsSummary(
                activeCount: activeCount,
                requestCount: requestCount,
                clients: clients,
                nextSession: nextSession,
                onOpenClients: onOpenClients ?? () {},
                onOpenRequests: onOpenRequests ?? () {},
                onOpenNotes: onOpenNotes ?? () {},
                onOpenNextSession: onOpenNextSession,
                onOpenClient: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpMyClients(
  WidgetTester tester, {
  required ThemeData theme,
  Size size = const Size(390, 844),
  double textScale = 1,
  List<ClientItem> clients = const [],
  List<ClientItem> requests = const [],
  Future<void> Function({required String leadId, required String status})?
      updateLeadStatus,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: ProviderMyClientsPage(
            providerType: 'trainer',
            clientPathPrefix: '/clients',
            initialClients: clients,
            initialRequests: requests,
            updateLeadStatus: updateLeadStatus,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('previewFromLead', () {
    test('prefers full name and copies username', () {
      final preview = previewFromLead(
        Lead(
          id: 'lead-1',
          clientId: 'c1',
          providerId: 'p1',
          providerType: 'trainer',
          status: 'accepted',
          createdAt: DateTime(2026, 8, 18),
          client: {
            'full_name': 'Gopinath Reddy',
            'username': 'don_5412',
            'avatar_url': null,
          },
        ),
      );
      expect(preview.name, 'Gopinath Reddy');
      expect(preview.subtitle, '@don_5412');
      expect(preview.avatarUrl, isNull);
    });

    test('falls back to username when name is empty', () {
      final preview = previewFromLead(
        Lead(
          id: 'lead-2',
          clientId: 'c2',
          providerId: 'p1',
          providerType: 'nutritionist',
          status: 'accepted',
          createdAt: DateTime(2026, 8, 18),
          client: {'full_name': '  ', 'username': 'no_name'},
        ),
      );
      expect(preview.name, 'no_name');
      expect(preview.subtitle, '@no_name');
    });
  });

  group('ProviderClientsSummary', () {
    testWidgets('shows Active, Requests, Notes without old dashboard copy',
        (tester) async {
      var openedClients = 0;
      var openedRequests = 0;
      var openedNotes = 0;
      await _pumpSummary(
        tester,
        theme: AppTheme.lightTheme,
        requestCount: 2,
        clients: const [
          ProviderClientPreview(
            id: 'c1',
            name: 'Ada Lovelace',
            subtitle: '@ada',
          ),
        ],
        onOpenClients: () => openedClients++,
        onOpenRequests: () => openedRequests++,
        onOpenNotes: () => openedNotes++,
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Manage your practice'), findsOneWidget);
      expect(find.text('Recent clients'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
      expect(find.text('See all'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Your practice'), findsNothing);
      expect(find.text('All Clients'), findsNothing);
      expect(find.text('All clients'), findsNothing);
      expect(find.text('Next session'), findsNothing);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(_redAttentionDots(), findsWidgets);

      await tester.tap(find.text('Requests'));
      await tester.pump();
      expect(openedRequests, 1);

      await tester.tap(find.text('Notes'));
      await tester.pump();
      expect(openedNotes, 1);

      await tester.tap(find.text('Active'));
      await tester.pump();
      expect(openedClients, 1);

      await tester.tap(find.text('See all'));
      await tester.pump();
      expect(openedClients, 2);
    });

    testWidgets('hides request attention when count is zero', (tester) async {
      await _pumpSummary(
        tester,
        theme: AppTheme.darkTheme,
        requestCount: 0,
        activeCount: 0,
      );
      expect(find.textContaining('No clients yet'), findsOneWidget);
      expect(
        find.textContaining('New client connections will appear here.'),
        findsOneWidget,
      );
      expect(_redAttentionDots(), findsNothing);
    });

    testWidgets('fits a small screen and long names without overflow',
        (tester) async {
      await _pumpSummary(
        tester,
        theme: AppTheme.lightTheme,
        size: const Size(320, 568),
        textScale: 1.3,
        requestCount: 14,
        nextSession: ProviderNextSessionPreview(
          sessionId: 's1',
          clientName: 'Gopinath Venkata Reddy',
          scheduledStart: DateTime(2026, 8, 19, 18, 30),
        ),
        clients: const [
          ProviderClientPreview(
            id: 'c1',
            name: 'Gopinath Venkata Reddy',
            subtitle: '@very_long_username_5412',
          ),
        ],
      );
      expect(find.text('Gopinath Venkata Reddy'), findsWidgets);
      expect(find.text('Next session'), findsOneWidget);
      expect(find.byType(VideoSessionAvatar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('light mode uses lavender tile and peach rows without borders',
        (tester) async {
      await _pumpSummary(
        tester,
        theme: AppTheme.lightTheme,
        clients: const [
          ProviderClientPreview(
            id: 'c1',
            name: 'Ada Lovelace',
            subtitle: '@ada',
          ),
        ],
      );

      expect(
        _tintedSurfaces(HomePremiumTheme.clientsManagementSurface(true)),
        findsWidgets,
      );
      expect(
        _tintedSurfaces(HomePremiumTheme.recentClientSurface(true)),
        findsWidgets,
      );
    });

    testWidgets('dark mode uses purple-tinted charcoal and warm rows',
        (tester) async {
      await _pumpSummary(
        tester,
        theme: AppTheme.darkTheme,
        clients: const [
          ProviderClientPreview(
            id: 'c1',
            name: 'Ada Lovelace',
            subtitle: '@ada',
          ),
        ],
      );

      expect(
        _tintedSurfaces(HomePremiumTheme.clientsManagementSurface(false)),
        findsWidgets,
      );
      expect(
        _tintedSurfaces(HomePremiumTheme.recentClientSurface(false)),
        findsWidgets,
      );
      expect(find.text('Recent clients'), findsOneWidget);
    });

    testWidgets('next session row is tappable only when a session exists',
        (tester) async {
      var openedSession = 0;
      await _pumpSummary(
        tester,
        theme: AppTheme.lightTheme,
        nextSession: ProviderNextSessionPreview(
          sessionId: 's1',
          clientName: 'Gopinath',
          scheduledStart: DateTime(2026, 8, 19, 18, 30),
        ),
        onOpenNextSession: () => openedSession++,
      );

      expect(find.text('Next session'), findsOneWidget);
      expect(find.textContaining('Gopinath'), findsOneWidget);
      await tester.tap(find.text('Next session'));
      await tester.pump();
      expect(openedSession, 1);
    });

    testWidgets('text scale 1.5 still fits Active/Requests/Notes',
        (tester) async {
      await _pumpSummary(
        tester,
        theme: AppTheme.lightTheme,
        size: const Size(360, 740),
        textScale: 1.5,
        requestCount: 12,
        clients: const [
          ProviderClientPreview(
            id: 'c1',
            name: 'Very Long Client Name Here',
            subtitle: '@long_handle_name',
          ),
        ],
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('nextSessionPreviewFromSessions', () {
    test('picks earliest upcoming session and hides ended ones', () {
      final now = DateTime.now();
      VideoSession session({
        required String id,
        required DateTime start,
        String status = 'scheduled',
        String? name,
      }) {
        return VideoSession(
          id: id,
          hostId: 'host',
          provider: 'google_meet',
          title: 'Session',
          scheduledStart: start,
          durationMinutes: 30,
          maxParticipants: 2,
          status: status,
          joinUrl: 'https://meet.google.com/abc',
          createdAt: now,
          counterpartyName: name,
        );
      }

      final preview = nextSessionPreviewFromSessions([
        session(
          id: 'later',
          start: now.add(const Duration(hours: 5)),
          name: 'Later Client',
        ),
        session(
          id: 'soon',
          start: now.add(const Duration(hours: 1)),
          name: 'Gopinath',
        ),
        session(
          id: 'ended',
          start: now.subtract(const Duration(hours: 2)),
          status: 'ended',
          name: 'Past Client',
        ),
      ]);

      expect(preview?.sessionId, 'soon');
      expect(preview?.clientName, 'Gopinath');
    });

    test('returns null when there is no upcoming session', () {
      expect(nextSessionPreviewFromSessions(const []), isNull);
      expect(nextSessionPreviewFromSessions(null), isNull);
    });

    test('formats today and tomorrow session times', () {
      final now = DateTime(2026, 8, 19, 9);
      expect(
        formatNextSessionWhen(DateTime(2026, 8, 19, 18, 30), now: now),
        'Today, 6:30 PM',
      );
      expect(
        formatNextSessionWhen(DateTime(2026, 8, 20, 7, 5), now: now),
        'Tomorrow, 7:05 AM',
      );
    });
  });

  group('ProviderMyClientsPage', () {
    testWidgets('uses Clients and Requests tabs without a plus button',
        (tester) async {
      await _pumpMyClients(
        tester,
        theme: AppTheme.lightTheme,
        clients: [
          _client(id: 'c1', name: 'Ada Lovelace', email: '@ada'),
        ],
        requests: [
          _client(
            id: 'c2',
            name: 'Alan Turing',
            status: ClientStatus.pending,
            leadId: 'lead-2',
            requestMessage: 'Please coach me',
          ),
        ],
      );

      expect(find.text('My Clients'), findsOneWidget);
      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('Requests 1'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Alan Turing'), findsNothing);
      expect(_redAttentionDots(), findsWidgets);

      await tester.tap(find.text('Requests 1'));
      await tester.pumpAndSettle();
      expect(find.text('Alan Turing'), findsOneWidget);
      expect(find.text('Please coach me'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Requests 1'), findsOneWidget);
      expect(_redAttentionDots(), findsWidgets);
    });

    testWidgets('accept moves the request into Clients and clears the dot',
        (tester) async {
      final updates = <String>[];
      await _pumpMyClients(
        tester,
        theme: AppTheme.lightTheme,
        requests: [
          _client(
            id: 'c2',
            name: 'Alan Turing',
            status: ClientStatus.pending,
            leadId: 'lead-2',
          ),
        ],
        updateLeadStatus: ({required leadId, required status}) async {
          updates.add('$leadId:$status');
        },
      );

      await tester.tap(find.text('Requests 1'));
      await tester.pumpAndSettle();
      expect(find.text('Alan Turing'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(updates, ['lead-2:accepted']);
      expect(find.text('Client accepted'), findsOneWidget);
      expect(find.text('No requests right now'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(_redAttentionDots(), findsNothing);

      await tester.tap(find.text('Clients'));
      await tester.pumpAndSettle();
      expect(find.text('Alan Turing'), findsOneWidget);
    });

    testWidgets('decline removes the request without adding a client',
        (tester) async {
      final updates = <String>[];
      await _pumpMyClients(
        tester,
        theme: AppTheme.darkTheme,
        clients: [
          _client(id: 'c1', name: 'Ada Lovelace'),
        ],
        requests: [
          _client(
            id: 'c2',
            name: 'Alan Turing',
            status: ClientStatus.pending,
            leadId: 'lead-2',
          ),
        ],
        updateLeadStatus: ({required leadId, required status}) async {
          updates.add('$leadId:$status');
        },
      );

      await tester.tap(find.text('Requests 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(updates, ['lead-2:declined']);
      expect(find.text('Request declined'), findsOneWidget);
      expect(find.text('Alan Turing'), findsNothing);

      await tester.tap(find.text('Clients'));
      await tester.pumpAndSettle();
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Alan Turing'), findsNothing);
    });

    testWidgets('blocks a second tap while accept is in flight', (tester) async {
      var calls = 0;
      final gate = Completer<void>();
      await _pumpMyClients(
        tester,
        theme: AppTheme.lightTheme,
        requests: [
          _client(
            id: 'c2',
            name: 'Alan Turing',
            status: ClientStatus.pending,
            leadId: 'lead-2',
          ),
        ],
        updateLeadStatus: ({required leadId, required status}) async {
          calls++;
          await gate.future;
        },
      );

      await tester.tap(find.text('Requests 1'));
      await tester.pumpAndSettle();

      final accept = find.byType(ElevatedButton);
      expect(accept, findsOneWidget);
      await tester.tap(accept);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.tap(accept);
      await tester.pump();
      expect(calls, 1);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('empty copy and missing avatar stay usable on a small screen',
        (tester) async {
      await _pumpMyClients(
        tester,
        theme: AppTheme.lightTheme,
        size: const Size(320, 568),
        textScale: 1.3,
        clients: [
          _client(
            id: 'c1',
            name: 'Gopinath Venkata Reddy',
            email: '@very_long_username_5412',
          ),
        ],
      );
      expect(find.text('Gopinath Venkata Reddy'), findsOneWidget);
      expect(find.byType(VideoSessionAvatar), findsWidgets);
      expect(tester.takeException(), isNull);

      await _pumpMyClients(
        tester,
        theme: AppTheme.darkTheme,
        size: const Size(320, 568),
      );
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('No requests right now'), findsOneWidget);
      expect(
        find.text('Pending client requests will appear here.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
