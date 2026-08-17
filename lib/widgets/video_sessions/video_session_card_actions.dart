import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Equal-size Join / Details row for upcoming session cards.
class VideoSessionCardActionRow extends StatelessWidget {
  static const double buttonHeight = 44;
  static const double gap = 10;
  static const double radius = 12;
  static const String joinLabel = 'Join';
  static const String detailsLabel = 'Details';

  final VoidCallback? onJoin;
  final VoidCallback onDetails;
  final Color outlineColor;

  const VideoSessionCardActionRow({
    super.key,
    required this.onDetails,
    required this.outlineColor,
    this.onJoin,
  });

  static ButtonStyle joinStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: DesignTokens.videoSessionsAccent,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: const Size(0, buttonHeight),
      maximumSize: const Size(double.infinity, buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static ButtonStyle detailsStyle(Color outlineColor) {
    return OutlinedButton.styleFrom(
      foregroundColor: outlineColor,
      minimumSize: const Size(0, buttonHeight),
      maximumSize: const Size(double.infinity, buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: outlineColor.withValues(alpha: 0.28)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    final details = SizedBox(
      height: buttonHeight,
      child: OutlinedButton(
        onPressed: onDetails,
        style: detailsStyle(outlineColor),
        child: const Text(
          detailsLabel,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: _labelStyle,
        ),
      ),
    );

    if (onJoin == null) {
      return SizedBox(height: buttonHeight, child: details);
    }

    return SizedBox(
      height: buttonHeight,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: onJoin,
                style: joinStyle(),
                child: const Text(
                  joinLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle,
                ),
              ),
            ),
          ),
          const SizedBox(width: gap),
          Expanded(child: details),
        ],
      ),
    );
  }
}
