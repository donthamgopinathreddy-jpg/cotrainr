import '../../../repositories/profile_repository.dart';

class VideoSessionNotificationPrefs {
  final bool sessions;
  final bool reminders;

  const VideoSessionNotificationPrefs({
    this.sessions = true,
    this.reminders = true,
  });

  VideoSessionNotificationPrefs copyWith({bool? sessions, bool? reminders}) {
    return VideoSessionNotificationPrefs(
      sessions: sessions ?? this.sessions,
      reminders: reminders ?? this.reminders,
    );
  }
}

abstract class VideoSessionNotificationPrefsStore {
  Future<VideoSessionNotificationPrefs> load();
  Future<void> save(VideoSessionNotificationPrefs prefs);
}

class ProfileVideoSessionNotificationPrefsStore
    implements VideoSessionNotificationPrefsStore {
  ProfileVideoSessionNotificationPrefsStore({ProfileRepository? repository})
      : _injected = repository;

  final ProfileRepository? _injected;
  ProfileRepository? _lazy;

  ProfileRepository get _repo => _injected ?? (_lazy ??= ProfileRepository());

  @override
  Future<VideoSessionNotificationPrefs> load() async {
    final remote = await _repo.fetchNotificationPreferences();
    return VideoSessionNotificationPrefs(
      sessions: remote['videoSessions'] ?? true,
      reminders: remote['videoSessionReminders'] ?? true,
    );
  }

  @override
  Future<void> save(VideoSessionNotificationPrefs prefs) async {
    final remote = await _repo.fetchNotificationPreferences();
    await _repo.updateNotificationPreferences(
      push: remote['push'] ?? true,
      community: remote['community'] ?? true,
      reminders: remote['reminders'] ?? true,
      achievements: remote['achievements'] ?? true,
      videoSessions: prefs.sessions,
      videoSessionReminders: prefs.reminders,
    );
  }
}
