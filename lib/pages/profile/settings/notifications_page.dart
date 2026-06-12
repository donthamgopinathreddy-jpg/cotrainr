import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/fitness_notification_preferences_service.dart';
import '../../../theme/account_hub_theme.dart';
import '../../../widgets/profile/account_hub_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = FitnessNotificationPreferencesService();
  FitnessNotificationPreferences _prefs = const FitnessNotificationPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _service.load();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    try {
      await _service.save(_prefs);
      if (mounted) {
        showHubSnackBar(context, 'Notification preferences saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showHubSnackBar(context, 'Could not save preferences');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setAll(bool v) => setState(() => _prefs = _prefs.copyWith(all: v));

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final cs = Theme.of(context).colorScheme;
    final dependentsEnabled = _prefs.all;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                HubSectionCard(
                  title: 'Push notifications',
                  animationDelayMs: 0,
                  child: Column(
                    children: [
                      HubToggleRow(
                        title: 'All notifications',
                        subtitle: 'Master switch for push notifications.',
                        value: _prefs.all,
                        onChanged: _setAll,
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Trainer messages',
                        subtitle: 'Messages from your coach.',
                        value: _prefs.trainerMessages,
                        enabled: dependentsEnabled,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(trainerMessages: v),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Nutritionist messages',
                        subtitle: 'Meal and nutrition guidance.',
                        value: _prefs.nutritionistMessages,
                        enabled: dependentsEnabled,
                        onChanged: (v) => setState(
                          () =>
                              _prefs = _prefs.copyWith(nutritionistMessages: v),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Meal reminders',
                        subtitle: 'Reminders to log meals.',
                        value: _prefs.mealReminders,
                        enabled: dependentsEnabled,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(mealReminders: v),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Water reminders',
                        subtitle: 'Hydration reminders.',
                        value: _prefs.waterReminders,
                        enabled: dependentsEnabled,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(waterReminders: v),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Workout reminders',
                        subtitle: 'Scheduled workout reminders.',
                        value: _prefs.workoutReminders,
                        enabled: dependentsEnabled,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(workoutReminders: v),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Goal progress',
                        subtitle:
                            'Weight, BMI, steps, and nutrition progress.',
                        value: _prefs.goalProgress,
                        enabled: dependentsEnabled,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(goalProgress: v),
                        ),
                      ),
                      const Divider(height: 1),
                      HubToggleRow(
                        title: 'Achievement alerts',
                        subtitle: 'Streaks and milestones.',
                        value: _prefs.achievementAlerts,
                        enabled: dependentsEnabled,
                        onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(achievementAlerts: v),
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
