import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/profile_repository.dart';
import 'water_reminder_service.dart';

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

abstract class FitnessNotificationPreferencesStore {
  Future<FitnessNotificationPreferences> load();
  Future<void> save(FitnessNotificationPreferences prefs);
}

class FitnessNotificationPreferencesService
    implements FitnessNotificationPreferencesStore {
  FitnessNotificationPreferencesService({
    ProfileRepository? profileRepository,
    Future<void> Function()? applyWaterGate,
  })  : _profileRepository = profileRepository ?? ProfileRepository(),
        _applyWaterGate = applyWaterGate ??
            (() => WaterReminderService.instance.applyPreferenceGate());

  static const prefix = 'fitness_notif_';
  static const allKey = '${prefix}all';
  static const waterRemindersKey = '${prefix}water_reminders';

  final ProfileRepository _profileRepository;
  final Future<void> Function() _applyWaterGate;

  /// Whether local water reminders may fire (master + water category).
  static Future<bool> allowsWaterReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final all = prefs.getBool(allKey) ?? true;
    final water = prefs.getBool(waterRemindersKey) ?? true;
    return all && water;
  }

  @override
  Future<FitnessNotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final remote = await _profileRepository.fetchNotificationPreferences();
    final all = remote['push'] ?? prefs.getBool(allKey) ?? true;

    return FitnessNotificationPreferences(
      all: all,
      trainerMessages: prefs.getBool('${prefix}trainer_messages') ?? true,
      nutritionistMessages:
          prefs.getBool('${prefix}nutritionist_messages') ?? true,
      mealReminders: prefs.getBool('${prefix}meal_reminders') ??
          (remote['reminders'] ?? true),
      waterReminders: prefs.getBool(waterRemindersKey) ?? true,
      workoutReminders: prefs.getBool('${prefix}workout_reminders') ?? true,
      goalProgress: prefs.getBool('${prefix}goal_progress') ??
          (remote['achievements'] ?? true),
      achievementAlerts: prefs.getBool('${prefix}achievement_alerts') ??
          (remote['achievements'] ?? true),
    );
  }

  @override
  Future<void> save(FitnessNotificationPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(allKey, prefs.all);
    await sp.setBool('${prefix}trainer_messages', prefs.trainerMessages);
    await sp.setBool(
      '${prefix}nutritionist_messages',
      prefs.nutritionistMessages,
    );
    await sp.setBool('${prefix}meal_reminders', prefs.mealReminders);
    await sp.setBool(waterRemindersKey, prefs.waterReminders);
    await sp.setBool('${prefix}workout_reminders', prefs.workoutReminders);
    await sp.setBool('${prefix}goal_progress', prefs.goalProgress);
    await sp.setBool('${prefix}achievement_alerts', prefs.achievementAlerts);

    await _profileRepository.updateNotificationPreferences(
      push: prefs.all,
      community: prefs.trainerMessages && prefs.nutritionistMessages,
      reminders: prefs.mealReminders &&
          prefs.waterReminders &&
          prefs.workoutReminders,
      achievements: prefs.goalProgress && prefs.achievementAlerts,
    );

    await _applyWaterGate();
  }
}
