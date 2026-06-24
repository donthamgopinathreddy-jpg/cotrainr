import 'package:flutter/material.dart';

import '../../services/water_reminder_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/insight_metric_theme.dart';

/// Bottom sheet for water reminder interval selection.
class WaterReminderPickerSheet extends StatefulWidget {
  final InsightMetricTheme theme;
  final double initialHours;

  const WaterReminderPickerSheet({
    super.key,
    required this.theme,
    required this.initialHours,
  });

  static Future<bool?> show(
    BuildContext context, {
    required InsightMetricTheme theme,
    required double initialHours,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WaterReminderPickerSheet(
        theme: theme,
        initialHours: initialHours,
      ),
    );
  }

  @override
  State<WaterReminderPickerSheet> createState() =>
      _WaterReminderPickerSheetState();
}

class _WaterReminderPickerSheetState extends State<WaterReminderPickerSheet> {
  late double _selectedHours;
  final _customController = TextEditingController();
  bool _isCustom = false;

  static const _options = <double>[0, 1, 2, 3];

  @override
  void initState() {
    super.initState();
    _selectedHours = widget.initialHours;
    _isCustom = !_options.contains(widget.initialHours) && widget.initialHours > 0;
    if (_isCustom) {
      _customController.text = widget.initialHours.toString();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String _label(double hours) {
    return WaterReminderService.instance.labelFor(hours);
  }

  Future<void> _save() async {
    final service = WaterReminderService.instance;
    final success = await service.setIntervalHours(_selectedHours);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not enable reminders. Check notification permission.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final sheetBg = isLight
        ? DesignTokens.lightCardBackground
        : InsightMetricTheme.surfaceCard;
    final titleColor = DesignTokens.textPrimaryOf(context);
    final subtitleColor = DesignTokens.textSecondaryOf(context);
    final borderColor = isLight
        ? DesignTokens.lightBorder
        : Colors.white.withValues(alpha: 0.12);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Water reminder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Get a local reminder to log your water intake.',
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 16),
              ..._options.map(
                (h) => ListTile(
                  title: Text(
                    _label(h),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  trailing: !_isCustom && _selectedHours == h
                      ? Icon(Icons.check_rounded, color: widget.theme.accent)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedHours = h;
                      _isCustom = false;
                      _customController.clear();
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Custom (hours)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 2.5',
                  hintStyle: TextStyle(color: subtitleColor),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: widget.theme.accent, width: 2),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      _isCustom = false;
                      return;
                    }
                    final parsed = double.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      _selectedHours = parsed;
                      _isCustom = true;
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: widget.theme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
