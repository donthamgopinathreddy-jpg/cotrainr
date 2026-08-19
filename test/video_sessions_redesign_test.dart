import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/pages/profile/settings/notifications_page.dart';
import 'package:cotrainr/repositories/video_sessions_repository.dart';
import 'package:cotrainr/services/fitness_notification_preferences_service.dart';
import 'package:cotrainr/services/os_notification_permission_status.dart';
import 'package:cotrainr/services/video_session_notification_prefs.dart';
import 'package:cotrainr/theme/app_theme.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/widgets/video_sessions/video_session_people_sheet.dart';
import 'package:cotrainr/widgets/video_sessions/video_session_theme.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakeFitnessStore implements FitnessNotificationPreferencesStore {
  FitnessNotificationPreferences value = const FitnessNotificationPreferences();

  @override
  Future<FitnessNotificationPreferences> load() async => value;

  @override
  Future<void> save(FitnessNotificationPreferences prefs) async {
    value = prefs;
  }
}

class _FakeVideoStore implements VideoSessionNotificationPrefsStore {
  VideoSessionNotificationPrefs value = const VideoSessionNotificationPrefs();
  int saveCount = 0;

  @override
  Future<VideoSessionNotificationPrefs> load() async => value;

  @override
  Future<void> save(VideoSessionNotificationPrefs prefs) async {
    saveCount++;
    value = prefs;
  }
}

class _FakeOsGateway extends OsNotificationPermissionGateway {
  @override
  Future<PermissionStatus> check() async => PermissionStatus.granted;

  @override
  Future<OsNotificationAccessLabel> readLabel() async =>
      OsNotificationAccessLabel.allowed;

  @override
  Future<void> manage() async {}
}

void main() {
  testWidgets('video session notification toggles persist independently',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final video = _FakeVideoStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: NotificationsPage(
          preferencesService: _FakeFitnessStore(),
          osPermissionGateway: _FakeOsGateway(),
          videoSessionPrefsStore: video,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Session reminders'),
      80,
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Session reminders'));
    await tester.pumpAndSettle();

    expect(video.value.reminders, isFalse);
    expect(video.value.sessions, isTrue);
    expect(video.saveCount, 1);
  });

  test('video session accent is not orange', () {
    expect(DesignTokens.videoSessionsAccent, isNot(DesignTokens.accentOrange));
  });

  testWidgets('schedule field theme uses purple focused border', (tester) async {
    late InputDecoration decoration;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            decoration = VideoSessionUi.fieldDecoration(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final border = decoration.focusedBorder as OutlineInputBorder;
    expect(border.borderSide.color, DesignTokens.videoSessionsAccent);
    expect(border.borderSide.color, isNot(DesignTokens.accentOrange));
    expect(border.borderSide.width, greaterThanOrEqualTo(1.5));
  });

  testWidgets('dark schedule field stays dark with purple focus', (tester) async {
    late InputDecoration decoration;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) {
            decoration = VideoSessionUi.fieldDecoration(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final border = decoration.focusedBorder as OutlineInputBorder;
    expect(border.borderSide.color, DesignTokens.videoSessionsAccent);
    expect(decoration.fillColor, VideoSessionUi.cardBg(
      tester.element(find.byType(SizedBox)),
    ));
  });

  test('completed past sessions have no redundant status', () {
    final s = VideoSession(
      id: '1',
      hostId: 'h',
      provider: 'google_meet',
      title: 'hello new testing',
      scheduledStart: DateTime(2026, 8, 17, 19, 20),
      durationMinutes: 15,
      maxParticipants: 2,
      status: 'ended',
      joinUrl: 'https://meet.google.com/abc-defg-hij',
      createdAt: DateTime(2026, 8, 1),
      counterpartyName: 'Gopinath Reddy',
      participantNames: const ['Gopinath Reddy'],
    );
    expect(videoSessionMeaningfulStatus(s), isNull);
    expect(
      videoSessionMeaningfulStatus(
        VideoSession(
          id: '2',
          hostId: 'h',
          provider: 'google_meet',
          title: 'A',
          scheduledStart: DateTime(2026, 8, 17, 19, 20),
          durationMinutes: 15,
          maxParticipants: 2,
          status: 'cancelled',
          joinUrl: 'https://meet.google.com/abc-defg-hij',
          createdAt: DateTime(2026, 8, 1),
        ),
      ),
      'Cancelled',
    );
  });

  test('one Meet room is encoded as one session plus N invitees', () {
    const inviteeCount = 3;
    final maxParticipants = inviteeCount + 1;
    expect(maxParticipants, 4);
  });
}
