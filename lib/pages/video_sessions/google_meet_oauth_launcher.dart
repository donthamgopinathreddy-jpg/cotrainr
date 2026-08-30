import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/video_sessions_repository.dart';
import '../../utils/video_session_error_messages.dart';
import '../../widgets/profile/account_hub_widgets.dart';

/// Opens the Google Meet OAuth consent screen in the external browser.
///
/// The redirect returns to the app as a deep link, which
/// `VideoSessionsPageV2` handles.
Future<void> launchGoogleMeetOAuth(
  BuildContext context,
  VideoSessionsRepository repo,
) async {
  try {
    final url = await repo.getGoogleOAuthUrl();
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (context.mounted) {
      showHubSnackBar(
        context,
        'Complete Google sign-in in the browser, then return here',
      );
    }
  } catch (e, s) {
    VideoSessionErrorMessages.log('launchGoogleMeetOAuth', e, s);
    if (context.mounted) {
      showHubSnackBar(context, VideoSessionErrorMessages.forConnect(e));
    }
  }
}
