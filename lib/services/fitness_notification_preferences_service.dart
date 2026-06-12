import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/profile_repository.dart';

/// Fitness-focused notification categories (device + Supabase master push).
class FitnessNotificationPreferences {
  final bool all;
  final bool trainerMessages;
  final bool nutritionistMessages;
  final bool mealReminders;
  final bool waterReminders;
  final bool workoutReminders;
  final bool goalProgress;
  final bool achievementAlerts;

  const FitnessNotificationPreferences({
    this.all = true,
    this.trainerMessages = true,
    this.nutritionistMessages = true,
    this.mealReminders = true,
    this.waterReminders = true,
    this.workoutReminders = true,
    this.goalProgress = true,
    this.achievementAlerts = true,
  });

  FitnessNotificationPreferences copyWith({
    bool? all,
    bool? trainerMessages,
    bool? nutritionistMessages,
    bool? mealReminders,
    bool? waterReminders,
    bool? workoutReminders,
    bool? goalProgress,
    bool? achievementAlerts,
  }) {
    return FitnessNotificationPreferences(
      all: all ?? this.all,
      trainerMessages: trainerMessages ?? this.trainerMessages,
      nutritionistMessages: nutritionistMessages ?? this.nutritionistMessages,
      mealReminders: mealReminders ?? this.mealReminders,
      waterReminders: waterReminders ?? this.waterReminders,
      workoutReminders: workoutReminders ?? this.workoutReminders,
      goalProgress: goalProgress ?? this.goalProgress,
      achievementAlerts: achievementAlerts ?? this.achievementAlerts,
    );
  }

  Map<String, bool> toJson() => {
        'all': all,
        'trainer_messages': trainerMessages,
        'nutritionist_messages': nutritionistMessages,
        'meal_reminders': mealReminders,
        'water_reminders': waterReminders,
        'workout_reminders': workoutReminders,
        'goal_progress': goalProgress,
        'achievement_alerts': achievementAlerts,
      };

  factory FitnessNotificationPreferences.fromJson(Map<String, bool> json) {
    return FitnessNotificationPreferences(
      all: json['all'] ?? true,
      trainerMessages: json['trainer_messages'] ?? true,
      nutritionistMessages: json['nutritionist_messages'] ?? true,
      mealReminders: json['meal_reminders'] ?? true,
      waterReminders: json['water_reminders'] ?? true,
      workoutReminders: json['workout_reminders'] ?? true,
      goalProgress: json['goal_progress'] ?? true,
      achievementAlerts: json['achievement_alerts'] ?? true,
    );
  }
}

class FitnessNotificationPreferencesService {
  static const _prefix = 'fitness_notif_';

  Future<FitnessNotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProfileRepository();
    final remote = await repo.fetchNotificationPreferences();
    final all = remote['push'] ?? prefs.getBool('${_prefix}all') ?? true;

    return FitnessNotificationPreferences(
      all: all,
      trainerMessages: prefs.getBool('${_prefix}trainer_messages') ?? true,
      nutritionistMessages:
          prefs.getBool('${_prefix}nutritionist_messages') ?? true,
      mealReminders: prefs.getBool('${_prefix}meal_reminders') ??
          (remote['reminders'] ?? true),
      waterReminders: prefs.getBool('${_prefix}water_reminders') ?? true,
      workoutReminders: prefs.getBool('${_prefix}workout_reminders') ?? true,
      goalProgress:
          prefs.getBool('${_prefix}goal_progress') ?? (remote['achievements'] ?? true),
      achievementAlerts: prefs.getBool('${_prefix}achievement_alerts') ??
          (remote['achievements'] ?? true),
    );
  }

  Future<void> save(FitnessNotificationPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('${_prefix}all', prefs.all);
    await sp.setBool('${_prefix}trainer_messages', prefs.trainerMessages);
    await sp.setBool('${_prefix}nutritionist_messages', prefs.nutritionistMessages);
    await sp.setBool('${_prefix}meal_reminders', prefs.mealReminders);
    await sp.setBool('${_prefix}water_reminders', prefs.waterReminders);
    await sp.setBool('${_prefix}workout_reminders', prefs.workoutReminders);
    await sp.setBool('${_prefix}goal_progress', prefs.goalProgress);
    await sp.setBool('${_prefix}achievement_alerts', prefs.achievementAlerts);

    final repo = ProfileRepository();
    await repo.updateNotificationPreferences(
      push: prefs.all,
      community: prefs.trainerMessages && prefs.nutritionistMessages,
      reminders: prefs.mealReminders &&
          prefs.waterReminders &&
          prefs.workoutReminders,
      achievements: prefs.goalProgress && prefs.achievementAlerts,
    );
  }
}
