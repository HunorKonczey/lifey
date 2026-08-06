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
    this.programAssignedPushEnabled = true,
    this.chatPushEnabled = true,
    this.chatQuietHoursStart,
    this.chatQuietHoursEnd,
    this.restTimerEnabled = true,
    this.defaultRestSeconds = 90,
    this.watchWorkoutEnabled = true,
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
        trainerGoalsPushEnabled = true,
        programAssignedPushEnabled = true,
        chatPushEnabled = true,
        chatQuietHoursStart = null,
        chatQuietHoursEnd = null,
        restTimerEnabled = true,
        defaultRestSeconds = 90,
        watchWorkoutEnabled = true;

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
  // Opt-out for the program-assigned push notification
  // (docs/34-multi-week-program-plan.md, M6) — same shape as
  // [workoutReminderEnabled] above.
  final bool programAssignedPushEnabled;
  // Opt-out for the chat push notification
  // (docs/chat/40-trainer-chat-plan.md §3.2) — same shape as
  // [workoutReminderEnabled] above, and deliberately role-independent: one
  // switch covers both the client's and the trainer's messages.
  final bool chatPushEnabled;

  /// Local-time window in which chat pushes are held back, in the shape the
  /// backend serializes a `LocalTime`: "HH:mm:ss". Both null means no window
  /// (docs/chat/40-trainer-chat-plan.md §5.4).
  final String? chatQuietHoursStart;
  final String? chatQuietHoursEnd;
  // Master switch for the rest-timer feature (docs/39-rest-timer-plan.md) —
  // same shape as [workoutReminderEnabled] above.
  final bool restTimerEnabled;
  // Default rest duration in seconds, used when an exercise has no
  // per-exercise override (docs/39-rest-timer-plan.md §2.2).
  final int defaultRestSeconds;
  // Master switch for starting/mirroring the workout on a paired watch
  // (docs/40-watch-app-plan.md §6.4) — same shape as [workoutReminderEnabled]
  // above.
  final bool watchWorkoutEnabled;

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
    bool? programAssignedPushEnabled,
    bool? chatPushEnabled,
    // Nullable fields need a "was it passed at all" marker, or clearing the
    // window would be indistinguishable from leaving it alone.
    Object? chatQuietHoursStart = _unset,
    Object? chatQuietHoursEnd = _unset,
    bool? restTimerEnabled,
    int? defaultRestSeconds,
    bool? watchWorkoutEnabled,
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
      programAssignedPushEnabled: programAssignedPushEnabled ?? this.programAssignedPushEnabled,
      chatPushEnabled: chatPushEnabled ?? this.chatPushEnabled,
      chatQuietHoursStart: chatQuietHoursStart == _unset
          ? this.chatQuietHoursStart
          : chatQuietHoursStart as String?,
      chatQuietHoursEnd: chatQuietHoursEnd == _unset
          ? this.chatQuietHoursEnd
          : chatQuietHoursEnd as String?,
      restTimerEnabled: restTimerEnabled ?? this.restTimerEnabled,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      watchWorkoutEnabled: watchWorkoutEnabled ?? this.watchWorkoutEnabled,
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
      programAssignedPushEnabled: json['programAssignedPushEnabled'] as bool? ?? true,
      chatPushEnabled: json['chatPushEnabled'] as bool? ?? true,
      chatQuietHoursStart: json['chatQuietHoursStart'] as String?,
      chatQuietHoursEnd: json['chatQuietHoursEnd'] as String?,
      restTimerEnabled: json['restTimerEnabled'] as bool? ?? true,
      defaultRestSeconds: json['defaultRestSeconds'] as int? ?? 90,
      watchWorkoutEnabled: json['watchWorkoutEnabled'] as bool? ?? true,
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
        'programAssignedPushEnabled': programAssignedPushEnabled,
        'chatPushEnabled': chatPushEnabled,
        'chatQuietHoursStart': chatQuietHoursStart,
        'chatQuietHoursEnd': chatQuietHoursEnd,
        // This client knows about quiet hours, so its values are authoritative.
        // Without the flag the server can't tell "the user cleared the window"
        // from "an app version that never sends these", and would keep the
        // stored window forever.
        'chatQuietHoursSet': true,
        'restTimerEnabled': restTimerEnabled,
        'defaultRestSeconds': defaultRestSeconds,
        'watchWorkoutEnabled': watchWorkoutEnabled,
      };
}

/// Sentinel for `copyWith`'s nullable fields — see the quiet-hours params.
const Object _unset = Object();
