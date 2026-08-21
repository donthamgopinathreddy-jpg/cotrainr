import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/video_sessions_repository.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/video_sessions/video_session_people_sheet.dart';
import '../../widgets/video_sessions/video_session_theme.dart';
import 'session_detail_page.dart';

class PastSessionsPage extends StatelessWidget {
  final List<VideoSession> sessions;

  const PastSessionsPage({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VideoSessionUi.pageBg(context),
      appBar: CotrainrAppBar(
        title: 'Past Sessions',
        fallbackRoute: '/video',
        backgroundColor: VideoSessionUi.pageBg(context),
      ),
      body: sessions.isEmpty
          ? Center(
              child: Text(
                'No past sessions yet.',
                style: TextStyle(color: VideoSessionUi.secondaryText(context)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return PastSessionRow(
                  session: sessions[index],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SessionDetailPage(
                        sessionId: sessions[index].id,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PastSessionRow extends StatelessWidget {
  final VideoSession session;
  final VoidCallback onTap;

  const PastSessionRow({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = videoSessionMeaningfulStatus(session);
    final when = DateFormat('d MMM · h:mm a').format(session.scheduledStart.toLocal());
    final counterpart = session.participantNames.isNotEmpty
        ? session.participantNames.first
        : (session.counterpartyName ?? session.withLine.replaceFirst('with ', ''));

    return Semantics(
      button: true,
      label: '${session.title}, $counterpart, $when',
      child: Material(
        color: VideoSessionUi.cardBg(context),
        borderRadius: BorderRadius.circular(VideoSessionUi.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VideoSessionUi.radius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VideoSessionUi.radius),
              border: Border.all(color: VideoSessionUi.border(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (status != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: videoSessionStatusColor(context, status),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        counterpart,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: VideoSessionUi.secondaryText(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$when · ${session.durationMinutes} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: VideoSessionUi.secondaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: VideoSessionUi.secondaryText(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
