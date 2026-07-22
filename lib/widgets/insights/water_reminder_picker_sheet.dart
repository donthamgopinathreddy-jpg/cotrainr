import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/water_reminder_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/insight_metric_theme.dart';
import '../common/pressable_card.dart';

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

  static const _presetMeta = <(int, String, String)>[
    (0, 'Off', 'No reminders'),
    (30, '30 min', 'Stay sharp'),
    (60, '1 hour', 'Steady pace'),
    (120, '2 hours', 'Balanced'),
    (180, '3 hours', 'Light nudges'),
  ];

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
        : const Color(0xFF0E1218);
    final titleColor = DesignTokens.textPrimaryOf(context);
    final subtitleColor = DesignTokens.textSecondaryOf(context);
    final accent = widget.theme.accent;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + safeBottom * 0.25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: subtitleColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SheetHero(accent: accent, isLight: isLight),
                const SizedBox(height: 20),
                Text(
                  'Reminder interval',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 10),
                for (final preset in _presetMeta) ...[
                  _IntervalCard(
                    title: preset.$2,
                    subtitle: preset.$3,
                    selected: !_isCustom && _selectedMinutes == preset.$1,
                    accent: accent,
                    isLight: isLight,
                    icon: preset.$1 == 0
                        ? Icons.notifications_off_outlined
                        : Icons.water_drop_rounded,
                    onTap: () => _selectPreset(preset.$1),
                  ),
                  const SizedBox(height: 8),
                ],
                _IntervalCard(
                  title: 'Custom',
                  subtitle: 'Set your own hours and minutes',
                  selected: _isCustom,
                  accent: accent,
                  isLight: isLight,
                  icon: Icons.tune_rounded,
                  onTap: _selectCustom,
                ),
                if (_isCustom) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          controller: _hoursController,
                          label: 'Hours',
                          accent: accent,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isLight: isLight,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          controller: _minutesController,
                          label: 'Minutes',
                          accent: accent,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isLight: isLight,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (_customMinutes != null &&
                      _customMinutes! > 0 &&
                      _customMinutes! < 30)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Minimum interval is 30 minutes.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: BorderSide(
                            color: InsightMetricTheme.borderColorOf(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: _canSave
                              ? LinearGradient(
                                  colors: [
                                    accent,
                                    Color.lerp(accent, Colors.white, 0.22)!,
                                  ],
                                )
                              : null,
                          color: _canSave
                              ? null
                              : accent.withValues(alpha: 0.28),
                          boxShadow: _canSave
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _canSave ? _save : null,
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              child: Center(
                                child: Text(
                                  'Save reminder',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
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
      ),
    );
  }
}

class _SheetHero extends StatelessWidget {
  final Color accent;
  final bool isLight;

  const _SheetHero({required this.accent, required this.isLight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [
                  accent.withValues(alpha: 0.16),
                  const Color(0xFF163B5A).withValues(alpha: 0.08),
                ]
              : const [
                  Color(0xFF163B5A),
                  Color(0xFF1E4A72),
                ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  accent,
                  Color.lerp(accent, Colors.white, 0.25)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay hydrated',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isLight
                        ? DesignTokens.lightTextPrimary
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cotrainr will nudge you to log water on your schedule.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: isLight
                        ? DesignTokens.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntervalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final bool isLight;
  final IconData icon;
  final VoidCallback onTap;

  const _IntervalCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.isLight,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = DesignTokens.textPrimaryOf(context);
    final subtitleColor = DesignTokens.textSecondaryOf(context);

    return PressableCard(
      onTap: onTap,
      borderRadius: 16,
      pressScale: 0.985,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: isLight ? 0.18 : 0.28),
                    accent.withValues(alpha: isLight ? 0.08 : 0.12),
                  ],
                )
              : null,
          color: selected
              ? null
              : (isLight
                  ? DesignTokens.lightMutedCardBackground
                  : Colors.white.withValues(alpha: 0.04)),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.7)
                : InsightMetricTheme.borderColorOf(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? accent
                    : accent.withValues(alpha: isLight ? 0.12 : 0.16),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: Icon(Icons.check_circle_rounded, color: accent, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color accent;
  final Color titleColor;
  final Color subtitleColor;
  final bool isLight;
  final ValueChanged<String> onChanged;

  const _TimeField({
    required this.controller,
    required this.label,
    required this.accent,
    required this.titleColor,
    required this.subtitleColor,
    required this.isLight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: titleColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: isLight
            ? DesignTokens.lightMutedCardBackground
            : Colors.white.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: InsightMetricTheme.borderColorOf(context),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
