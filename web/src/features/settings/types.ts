export type UnitSystem = "METRIC" | "IMPERIAL";
export type ThemePreference = "LIGHT" | "DARK" | "SYSTEM";
export type LanguagePreference = "SYSTEM" | "ENGLISH" | "HUNGARIAN";

export interface SettingsResponse {
  unitSystem: UnitSystem;
  dailyCalorieGoal: number;
  dailyProteinGoal: number;
  dailyCarbsGoal: number;
  dailyFatGoal: number;
  dailyWaterGoalLiters: number;
  dailyStepGoal: number;
  theme: ThemePreference;
  language: LanguagePreference;
}

export type SettingsRequest = SettingsResponse;
