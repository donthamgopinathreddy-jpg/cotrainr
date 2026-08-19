import 'package:intl/intl.dart';

import '../repositories/coach_notes_repository.dart';

const kClientNotesScreenTitle = 'Notes';
const kClientNotesExploreTitle = 'Notes';
const kClientNotesExploreSubtitle =
    'Feedback from your trainers & nutritionists';

class ClientNotesProviderGroup {
  final String providerId;
  final String name;
  final String? avatarUrl;
  final String? roleLabel;
  final List<CoachNote> notes;

  const ClientNotesProviderGroup({
    required this.providerId,
    required this.name,
    required this.notes,
    this.avatarUrl,
    this.roleLabel,
  });

  int get noteCount => notes.length;

  DateTime get latestAt => notes.first.createdAt;
}

/// Groups inbox notes by author. Newest note first within a group;
/// groups ordered by latest note descending.
///
/// [viewerClientId] is a display-only filter. RLS remains the security boundary.
List<ClientNotesProviderGroup> groupClientNotesByProvider(
  List<CoachNote> notes, {
  String? viewerClientId,
}) {
  final filtered = viewerClientId == null
      ? notes
      : notes.where((n) => n.clientId == viewerClientId);

  final byProvider = <String, List<CoachNote>>{};
  for (final note in filtered) {
    if (note.coachId.isEmpty || note.id.isEmpty) continue;
    byProvider.putIfAbsent(note.coachId, () => []).add(note);
  }

  final groups = <ClientNotesProviderGroup>[];
  for (final entry in byProvider.entries) {
    final sorted = [...entry.value]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = sorted.first;
    groups.add(
      ClientNotesProviderGroup(
        providerId: entry.key,
        name: _displayName(latest),
        avatarUrl: latest.coachAvatarUrl,
        roleLabel: providerRoleLabel(latest.coachType),
        notes: sorted,
      ),
    );
  }

  groups.sort((a, b) => b.latestAt.compareTo(a.latestAt));
  return groups;
}

String? providerRoleLabel(String? providerType) {
  switch ((providerType ?? '').trim().toLowerCase()) {
    case 'trainer':
      return 'Trainer';
    case 'nutritionist':
      return 'Nutritionist';
    default:
      return null;
  }
}

String formatNoteDateShort(DateTime value) {
  return DateFormat('d MMM').format(value.toLocal());
}

String formatNoteDateLong(DateTime value) {
  return DateFormat('d MMM yyyy').format(value.toLocal());
}

String noteCountLabel(int count) {
  return count == 1 ? '1 note' : '$count notes';
}

String _displayName(CoachNote note) {
  final name = (note.coachName ?? '').trim();
  if (name.isNotEmpty) return name;
  return providerRoleLabel(note.coachType) ?? '';
}
