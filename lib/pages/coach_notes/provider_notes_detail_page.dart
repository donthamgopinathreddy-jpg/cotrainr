import 'package:flutter/material.dart';

import '../../utils/client_notes_grouping.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';
import '../../widgets/video_sessions/video_session_theme.dart';

class ProviderNotesDetailPage extends StatelessWidget {
  final ClientNotesProviderGroup group;

  const ProviderNotesDetailPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final role = group.roleLabel;
    final title = group.name.isEmpty ? (role ?? 'Notes') : group.name;

    return Scaffold(
      backgroundColor: VideoSessionUi.pageBg(context),
      appBar: CotrainrAppBar(
        backgroundColor: VideoSessionUi.pageBg(context),
        foregroundColor: HomePremiumTheme.primaryText(isLight),
        titleWidget: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (role != null)
              Text(
                role,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: HomePremiumTheme.secondaryText(isLight),
                ),
              ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: group.notes.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Row(
                children: [
                  VideoSessionAvatar(
                    name: group.name,
                    imageUrl: group.avatarUrl,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'NOTES',
                    style: VideoSessionUi.sectionLabel(context),
                  ),
                ],
              ),
            );
          }
          final note = group.notes[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: VideoSessionUi.cardBox(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatNoteDateLong(note.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HomePremiumTheme.secondaryText(isLight),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: HomePremiumTheme.primaryText(isLight),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
