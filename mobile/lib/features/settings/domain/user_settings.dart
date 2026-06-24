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
        dailyStepGoal = null;

  final UnitSystem unitSystem;
  final ThemePreference theme;
  final LanguagePreference language;
  final int? dailyCalorieGoal;
  final int? dailyProteinGoal;
  final int? dailyCarbsGoal;
  final int? dailyFatGoal;
  final double? dailyWaterGoalLiters;
  final int? dailyStepGoal;

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
      };
}
