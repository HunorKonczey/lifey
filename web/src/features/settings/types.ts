export type UnitSystem = "METRIC" | "IMPERIAL";
export type ThemePreference = "LIGHT" | "DARK" | "SYSTEM";
export type LanguagePreference = "SYSTEM" | "ENGLISH" | "HUNGARIAN";

export interface SettingsResponse {
  unitSystem: UnitSystem;
  dailyCalorieGoal: number | null;
  dailyProteinGoal: number | null;
  dailyCarbsGoal: number | null;
  dailyFatGoal: number | null;
  dailyWaterGoalLiters: number | null;
  dailyStepGoal: number | null;
  theme: ThemePreference;
  language: LanguagePreference;
}

export type SettingsRequest = SettingsResponse;
