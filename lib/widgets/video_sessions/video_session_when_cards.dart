import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/design_tokens.dart';
import 'video_session_theme.dart';

class VideoSessionWhenCards extends StatelessWidget {
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final String? errorText;

  const VideoSessionWhenCards({
    super.key,
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final dateCard = _WhenCard(
      icon: Icons.calendar_today_rounded,
      label: 'DATE',
      primary: date == null ? 'Select date' : DateFormat('d MMM yyyy').format(date!),
      secondary: date == null ? 'Tap to choose' : DateFormat('EEEE').format(date!),
      semanticLabel: date == null
          ? 'Select date'
          : 'Date ${DateFormat('EEEE, d MMMM yyyy').format(date!)}',
      onTap: onPickDate,
    );
    final timeCard = _WhenCard(
      icon: Icons.schedule_rounded,
      label: 'START TIME',
      primary: time == null ? 'Select time' : time!.format(context),
      secondary: 'Local time',
      semanticLabel: time == null
          ? 'Select start time'
          : 'Start time ${time!.format(context)}, local time',
      onTap: onPickTime,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (narrow)
          Column(
            children: [
              dateCard,
              const SizedBox(height: 10),
              timeCard,
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: dateCard),
              const SizedBox(width: 10),
              Expanded(child: timeCard),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          'Times shown in your local timezone.',
          style: TextStyle(
            fontSize: 12,
            color: VideoSessionUi.secondaryText(context),
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ],
    );
  }
}

class _WhenCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String primary;
  final String secondary;
  final String semanticLabel;
  final VoidCallback onTap;

  const _WhenCard({
    required this.icon,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VideoSessionUi.radius),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: VideoSessionUi.cardBox(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: DesignTokens.videoSessionsAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: VideoSessionUi.secondaryText(context),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: VideoSessionUi.secondaryText(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: VideoSessionUi.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<DateTime?> showVideoSessionDatePicker({
  required BuildContext context,
  required DateTime initialDate,
}) {
  return showDatePicker(
    context: context,
    helpText: 'Select date',
    cancelText: 'Cancel',
    confirmText: 'Done',
    initialDate: initialDate,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    builder: (ctx, child) => Theme(
      data: VideoSessionUi.pickerTheme(context),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

Future<TimeOfDay?> showVideoSessionTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    helpText: 'Select start time',
    cancelText: 'Cancel',
    confirmText: 'Done',
    initialTime: initialTime,
    builder: (ctx, child) => Theme(
      data: VideoSessionUi.pickerTheme(context),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
