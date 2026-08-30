import 'package:flutter/material.dart';

import '../../repositories/video_sessions_repository.dart';
import '../../theme/design_tokens.dart';
import 'video_session_avatar.dart';
import 'video_session_theme.dart';

Future<void> showVideoSessionPeopleSheet({
  required BuildContext context,
  required VideoSession session,
  String? myUserId,
}) {
  final people = session.people.isNotEmpty
      ? session.people
      : session.participantNames
          .map(
            (name) => VideoSessionPerson(
              userId: name,
              displayName: name,
            ),
          )
          .toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: VideoSessionUi.cardBg(ctx),
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: VideoSessionUi.border(ctx),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Participants',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: people.isEmpty ? 1 : people.length,
                      itemBuilder: (_, i) {
                        if (people.isEmpty) {
                          return ListTile(
                            title: Text(
                              session.withLine,
                              style: TextStyle(
                                color: VideoSessionUi.secondaryText(ctx),
                              ),
                            ),
                          );
                        }
                        final person = people[i];
                        final name = person.displayName.trim().isEmpty
                            ? 'Unnamed profile'
                            : person.displayName.trim();
                        return ListTile(
                          leading: VideoSessionAvatar(
                            name: name,
                            imageUrl: person.avatarUrl,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: VideoSessionResponseChip(
                            responseStatus: session.responseStatusFor(
                              person,
                              myUserId: myUserId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class VideoSessionWithLine extends StatelessWidget {
  final VideoSession session;
  final String? myUserId;

  const VideoSessionWithLine({
    super.key,
    required this.session,
    this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    final summary = session.participantResponseSummary;
    return Semantics(
      button: true,
      label: 'Participants: ${session.withLine}',
      child: InkWell(
        onTap: () => showVideoSessionPeopleSheet(
          context: context,
          session: session,
          myUserId: myUserId,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.withLine,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: VideoSessionUi.secondaryText(context),
                ),
              ),
              if (summary != null)
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VideoSessionUi.secondaryText(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-participant attendance response.
///
/// Renders nothing when the response is unknown or still pending, so an
/// unanswered invite is never shown as a decision.
class VideoSessionResponseChip extends StatelessWidget {
  final String? responseStatus;

  const VideoSessionResponseChip({super.key, this.responseStatus});

  @override
  Widget build(BuildContext context) {
    final status = responseStatus?.trim().toLowerCase();
    final String label;
    final Color color;
    switch (status) {
      case 'rejected':
        label = 'Declined';
        color = const Color(0xFFDC2626);
        break;
      case 'accepted':
        label = 'Accepted';
        color = DesignTokens.videoSessionsAccent;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Session-level status label, or null when the session is simply upcoming.
///
/// A single decline in a group session is a participant fact, not a session
/// fact, so it must not label the whole session.
String? videoSessionMeaningfulStatus(VideoSession session) {
  if (session.isCancelled) return 'Cancelled';
  if (session.hasRejected || session.counterpartRejectedOneToOne) {
    return 'Rejected';
  }
  return null;
}

Color videoSessionStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'Cancelled':
    case 'Rejected':
    case 'Missed':
      return const Color(0xFFDC2626);
    default:
      return DesignTokens.videoSessionsAccent;
  }
}
