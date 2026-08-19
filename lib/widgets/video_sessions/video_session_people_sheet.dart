import 'package:flutter/material.dart';

import '../../repositories/video_sessions_repository.dart';
import '../../theme/design_tokens.dart';
import 'video_session_avatar.dart';
import 'video_session_theme.dart';

Future<void> showVideoSessionPeopleSheet({
  required BuildContext context,
  required VideoSession session,
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

  const VideoSessionWithLine({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Participants: ${session.withLine}',
      child: InkWell(
        onTap: () => showVideoSessionPeopleSheet(
          context: context,
          session: session,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            session.withLine,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: VideoSessionUi.secondaryText(context),
            ),
          ),
        ),
      ),
    );
  }
}

String? videoSessionMeaningfulStatus(VideoSession session) {
  if (session.isCancelled) return 'Cancelled';
  if (session.hasRejected || session.counterpartRejected) return 'Rejected';
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
