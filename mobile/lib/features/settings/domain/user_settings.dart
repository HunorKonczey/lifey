enum UnitSystem { metric, imperial }

enum ThemePreference { light, dark, system }

enum LanguagePreference { system, english, hungarian }

/// Domain model for the per-user settings (`/settings`): units, daily
/// calorie/macro goals, and theme preference.
class UserSettings {
  const UserSettings({
    required this.unitSystem,
    required this.theme,
    required this.language,
    this.dailyCalorieGoal,
    this.dailyProteinGoal,
    this.dailyCarbsGoal,
    this.dailyFatGoal,
    this.dailyWaterGoalLiters,
    this.dailyStepGoal,
    this.workoutReminderEnabled = true,
    this.trainerCommentPushEnabled = true,
    this.trainerGoalsPushEnabled = true,
  });

  const UserSettings.defaults()
      : unitSystem = UnitSystem.metric,
        theme = ThemePreference.system,
        language = LanguagePreference.system,
        dailyCalorieGoal = null,
        dailyProteinGoal = null,
        dailyCarbsGoal = null,
        dailyFatGoal = null,
        dailyWaterGoalLiters = null,
        dailyStepGoal = null,
        workoutReminderEnabled = true,
        trainerCommentPushEnabled = true,
        trainerGoalsPushEnabled = true;

  final UnitSystem unitSystem;
  final ThemePreference theme;
  final LanguagePreference language;
  final int? dailyCalorieGoal;
  final int? dailyProteinGoal;
  final int? dailyCarbsGoal;
  final int? dailyFatGoal;
  final double? dailyWaterGoalLiters;
  final int? dailyStepGoal;
  // Opt-out for the trainer-scheduled-workout push reminder
  // (docs/30-push-notifications-plan.md) — server-enforced (the backend job
  // checks it), synced like every other field here rather than a local pref.
  final bool workoutReminderEnabled;
  // Opt-out for the trainer-comment push notification
  // (docs/31-session-feedback-loop-plan.md) — same shape as
  // [workoutReminderEnabled] above.
  final bool trainerCommentPushEnabled;
  // Opt-out for the trainer-nutrition-goals-changed push notification
  // (docs/32-trainer-nutrition-goals-plan.md) — same shape as
  // [workoutReminderEnabled] above.
  final bool trainerGoalsPushEnabled;

  UserSettings copyWith({
    UnitSystem? unitSystem,
    ThemePreference? theme,
    LanguagePreference? language,
    int? dailyCalorieGoal,
    int? dailyProteinGoal,
    int? dailyCarbsGoal,
    int? dailyFatGoal,
    double? dailyWaterGoalLiters,
    int? dailyStepGoal,
    bool? workoutReminderEnabled,
    bool? trainerCommentPushEnabled,
    bool? trainerGoalsPushEnabled,
  }) {
    return UserSettings(
      unitSystem: unitSystem ?? this.unitSystem,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      dailyProteinGoal: dailyProteinGoal ?? this.dailyProteinGoal,
      dailyCarbsGoal: dailyCarbsGoal ?? this.dailyCarbsGoal,
      dailyFatGoal: dailyFatGoal ?? this.dailyFatGoal,
      dailyWaterGoalLiters: dailyWaterGoalLiters ?? this.dailyWaterGoalLiters,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      workoutReminderEnabled: workoutReminderEnabled ?? this.workoutReminderEnabled,
      trainerCommentPushEnabled: trainerCommentPushEnabled ?? this.trainerCommentPushEnabled,
      trainerGoalsPushEnabled: trainerGoalsPushEnabled ?? this.trainerGoalsPushEnabled,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      unitSystem: UnitSystem.values.byName((json['unitSystem'] as String).toLowerCase()),
      theme: ThemePreference.values.byName((json['theme'] as String).toLowerCase()),
      language: LanguagePreference.values.byName((json['language'] as String).toLowerCase()),
      dailyCalorieGoal: json['dailyCalorieGoal'] as int?,
      dailyProteinGoal: json['dailyProteinGoal'] as int?,
      dailyCarbsGoal: json['dailyCarbsGoal'] as int?,
      dailyFatGoal: json['dailyFatGoal'] as int?,
      dailyWaterGoalLiters: (json['dailyWaterGoalLiters'] as num?)?.toDouble(),
      dailyStepGoal: json['dailyStepGoal'] as int?,
      workoutReminderEnabled: json['workoutReminderEnabled'] as bool? ?? true,
      trainerCommentPushEnabled: json['trainerCommentPushEnabled'] as bool? ?? true,
      trainerGoalsPushEnabled: json['trainerGoalsPushEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'unitSystem': unitSystem.name.toUpperCase(),
        'dailyCalorieGoal': dailyCalorieGoal,
        'dailyProteinGoal': dailyProteinGoal,
        'dailyCarbsGoal': dailyCarbsGoal,
        'dailyFatGoal': dailyFatGoal,
        'dailyWaterGoalLiters': dailyWaterGoalLiters,
        'dailyStepGoal': dailyStepGoal,
        'theme': theme.name.toUpperCase(),
        'language': language.name.toUpperCase(),
        'workoutReminderEnabled': workoutReminderEnabled,
        'trainerCommentPushEnabled': trainerCommentPushEnabled,
        'trainerGoalsPushEnabled': trainerGoalsPushEnabled,
      };
}
