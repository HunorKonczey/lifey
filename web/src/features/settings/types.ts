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
  /** Master switch for chat notifications (docs/chat/40-trainer-chat-plan.md §3.2). */
  chatPushEnabled: boolean;
  /**
   * Local-time window in which chat pushes are held back, "HH:mm:ss" as the
   * backend serializes a `LocalTime`. Both null means no window (§5.4).
   */
  chatQuietHoursStart: string | null;
  chatQuietHoursEnd: string | null;
}

/**
 * Sent as-is from the loaded response, so fields this client doesn't model
 * (the other push toggles) round-trip untouched rather than being reset.
 */
export type SettingsRequest = SettingsResponse & {
  /**
   * Tells the server "I mean it" about the quiet-hours fields. Absent means
   * "leave the stored window alone", which is what keeps an older client from
   * silently wiping a window set elsewhere.
   */
  chatQuietHoursSet?: boolean;
};
