import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/video_sessions/video_session_theme.dart';

/// Visual language for trainer/nutritionist client monitoring.
/// Reuses Video Sessions / DesignTokens — not a new design system.
abstract final class ClientMonitoringUi {
  static const radius = VideoSessionUi.radius;
  static const pagePadding = 16.0;
  static const avatarSize = 56.0;
  static const actionHeight = 48.0;
  static const motion = VideoSessionUi.duration;

  static Color pageBg(BuildContext context) => VideoSessionUi.pageBg(context);

  static Color cardBg(BuildContext context) => VideoSessionUi.cardBg(context);

  static Color border(BuildContext context) => VideoSessionUi.border(context);

  static Color secondary(BuildContext context) =>
      VideoSessionUi.secondaryText(context);

  static TextStyle sectionLabel(BuildContext context) =>
      VideoSessionUi.sectionLabel(context);

  static TextStyle title(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textPrimaryOf(context),
    );
  }

  static TextStyle value(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: DesignTokens.textPrimaryOf(context),
    );
  }

  static BoxDecoration cardBox(BuildContext context) =>
      VideoSessionUi.cardBox(context);

  static Duration motionOf(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : motion;
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String shortDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]}';
  }

  static String timeOfDay(DateTime value) {
    final local = value.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }
}
