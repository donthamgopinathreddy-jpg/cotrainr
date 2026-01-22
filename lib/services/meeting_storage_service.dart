import '../models/video_session_models.dart';

class MeetingStorageService {
  static final MeetingStorageService _instance = MeetingStorageService._internal();
  factory MeetingStorageService() => _instance;
  MeetingStorageService._internal();

  final List<Meeting> _meetings = [];

  List<Meeting> get allMeetings => List.unmodifiable(_meetings);

  List<Meeting> get ongoingMeetings {
    // Only show meetings that are actually live/ongoing
    return _meetings
        .where((m) => m.status == MeetingStatus.live)
        .toList()
      ..sort((a, b) => (a.scheduledFor ?? DateTime.now())
          .compareTo(b.scheduledFor ?? DateTime.now()));
  }

  List<Meeting> get upcomingMeetings {
    final now = DateTime.now();
    return _meetings
        .where((m) => m.status == MeetingStatus.upcoming && 
            m.scheduledFor != null && 
            m.scheduledFor!.isAfter(now))
        .toList()
      ..sort((a, b) => (a.scheduledFor ?? DateTime.now())
          .compareTo(b.scheduledFor ?? DateTime.now()));
  }

  List<Meeting> get recentMeetings {
    return _meetings
        .where((m) => m.status == MeetingStatus.ended)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void addMeeting(Meeting meeting) {
    _meetings.add(meeting);
  }

  void removeMeeting(String meetingId) {
    _meetings.removeWhere((m) => m.meetingId == meetingId);
  }

  Meeting? getMeetingById(String meetingId) {
    try {
      return _meetings.firstWhere((m) => m.meetingId == meetingId);
    } catch (e) {
      return null;
    }
  }

  void updateMeetingStatus(String meetingId, MeetingStatus newStatus) {
    final index = _meetings.indexWhere((m) => m.meetingId == meetingId);
    if (index != -1) {
      final meeting = _meetings[index];
      // Create a new Meeting instance with updated status
      final updatedMeeting = Meeting(
        meetingId: meeting.meetingId,
        title: meeting.title,
        hostUserId: meeting.hostUserId,
        hostRole: meeting.hostRole,
        createdAt: meeting.createdAt,
        scheduledFor: meeting.scheduledFor,
        startedAt: meeting.startedAt,
        durationMins: meeting.durationMins,
        maxParticipants: meeting.maxParticipants,
        isInstant: meeting.isInstant,
        participantsCount: meeting.participantsCount,
        status: newStatus,
        joinCode: meeting.joinCode,
        privacy: meeting.privacy,
        allowedRoles: meeting.allowedRoles,
        notes: meeting.notes,
      );
      _meetings[index] = updatedMeeting;
    }
  }

  void checkAndUpdateUpcomingMeetings() {
    final now = DateTime.now();
    for (final meeting in _meetings) {
      if (meeting.status == MeetingStatus.upcoming &&
          meeting.scheduledFor != null &&
          meeting.scheduledFor!.isBefore(now)) {
        // Set startedAt when meeting becomes live
        final index = _meetings.indexWhere((m) => m.meetingId == meeting.meetingId);
        if (index != -1) {
          final updatedMeeting = Meeting(
            meetingId: meeting.meetingId,
            title: meeting.title,
            hostUserId: meeting.hostUserId,
            hostRole: meeting.hostRole,
            createdAt: meeting.createdAt,
            scheduledFor: meeting.scheduledFor,
            startedAt: now, // Set start time when meeting goes live
            durationMins: meeting.durationMins,
            maxParticipants: meeting.maxParticipants,
            isInstant: meeting.isInstant,
            participantsCount: meeting.participantsCount,
            status: MeetingStatus.live,
            joinCode: meeting.joinCode,
            privacy: meeting.privacy,
            allowedRoles: meeting.allowedRoles,
            notes: meeting.notes,
          );
          _meetings[index] = updatedMeeting;
        }
      }
    }
  }

  void setMeetingStartedAt(String meetingId, DateTime startedAt) {
    final index = _meetings.indexWhere((m) => m.meetingId == meetingId);
    if (index != -1) {
      final meeting = _meetings[index];
      final updatedMeeting = Meeting(
        meetingId: meeting.meetingId,
        title: meeting.title,
        hostUserId: meeting.hostUserId,
        hostRole: meeting.hostRole,
        createdAt: meeting.createdAt,
        scheduledFor: meeting.scheduledFor,
        startedAt: startedAt,
        durationMins: meeting.durationMins,
        maxParticipants: meeting.maxParticipants,
        isInstant: meeting.isInstant,
        participantsCount: meeting.participantsCount,
        status: meeting.status,
        joinCode: meeting.joinCode,
        privacy: meeting.privacy,
        allowedRoles: meeting.allowedRoles,
        notes: meeting.notes,
      );
      _meetings[index] = updatedMeeting;
    }
  }

  void clear() {
    _meetings.clear();
  }
}
