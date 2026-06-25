import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/water_reminder_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/insight_metric_theme.dart';

/// Bottom sheet for drinking reminder interval selection.
class WaterReminderPickerSheet extends StatefulWidget {
  final InsightMetricTheme theme;
  final int initialMinutes;

  const WaterReminderPickerSheet({
    super.key,
    required this.theme,
    required this.initialMinutes,
  });

  static Future<bool?> show(
    BuildContext context, {
    required InsightMetricTheme theme,
    required int initialMinutes,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WaterReminderPickerSheet(
        theme: theme,
        initialMinutes: initialMinutes,
      ),
    );
  }

  @override
  State<WaterReminderPickerSheet> createState() =>
      _WaterReminderPickerSheetState();
}

class _WaterReminderPickerSheetState extends State<WaterReminderPickerSheet> {
  late int _selectedMinutes;
  bool _isCustom = false;
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
    _isCustom = widget.initialMinutes > 0 &&
        !WaterReminderService.isPreset(widget.initialMinutes);
    if (_isCustom) {
      final total = widget.initialMinutes;
      _hoursController.text = '${total ~/ 60}';
      final mins = total % 60;
      if (mins > 0) _minutesController.text = '$mins';
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  int? get _customMinutes {
    final hours = int.tryParse(_hoursController.text.trim()) ?? 0;
    final mins = int.tryParse(_minutesController.text.trim()) ?? 0;
    if (hours <= 0 && mins <= 0) return null;
    return hours * 60 + mins;
  }

  int? get _effectiveMinutes {
    if (_isCustom) return _customMinutes;
    return _selectedMinutes;
  }

  bool get _canSave {
    final minutes = _effectiveMinutes;
    if (minutes == null) return _selectedMinutes == 0 && !_isCustom;
    if (minutes == 0) return true;
    return minutes >= 30;
  }

  Future<void> _save() async {
    final minutes = _effectiveMinutes ?? 0;
    if (minutes > 0 && minutes < 30) return;

    final success =
        await WaterReminderService.instance.setIntervalMinutes(minutes);
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

  void _selectPreset(int minutes) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMinutes = minutes;
      _isCustom = false;
      _hoursController.clear();
      _minutesController.clear();
    });
  }

  void _selectCustom() {
    HapticFeedback.selectionClick();
    setState(() {
      _isCustom = true;
      if (_hoursController.text.isEmpty && _minutesController.text.isEmpty) {
        if (_selectedMinutes > 0 &&
            !WaterReminderService.isPreset(_selectedMinutes)) {
          _hoursController.text = '${_selectedMinutes ~/ 60}';
          final mins = _selectedMinutes % 60;
          if (mins > 0) _minutesController.text = '$mins';
        }
      }
    });
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
    final pillBg = InsightMetricTheme.surfaceCardOf(context);

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
                'Drinking reminder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how often Cotrainr should remind you to drink water.',
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in WaterReminderService.presetMinutes)
                    _ReminderPill(
                      label: WaterReminderService.pillLabel(minutes),
                      selected: !_isCustom && _selectedMinutes == minutes,
                      accent: widget.theme.accent,
                      unselectedBg: pillBg,
                      titleColor: titleColor,
                      borderColor: borderColor,
                      onTap: () => _selectPreset(minutes),
                    ),
                  _ReminderPill(
                    label: 'Custom',
                    selected: _isCustom,
                    accent: widget.theme.accent,
                    unselectedBg: pillBg,
                    titleColor: titleColor,
                    borderColor: borderColor,
                    onTap: _selectCustom,
                  ),
                ],
              ),
              if (_isCustom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hoursController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'hours',
                          hintStyle: TextStyle(color: subtitleColor),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.theme.accent,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'minutes',
                          hintStyle: TextStyle(color: subtitleColor),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.theme.accent,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (_customMinutes != null &&
                    _customMinutes! > 0 &&
                    _customMinutes! < 30)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Minimum interval is 30 minutes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ),
              ],
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
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: widget.theme.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            widget.theme.accent.withValues(alpha: 0.35),
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.7),
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

class _ReminderPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color unselectedBg;
  final Color titleColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ReminderPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.unselectedBg,
    required this.titleColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : unselectedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? accent : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : titleColor,
          ),
        ),
      ),
    );
  }
}
