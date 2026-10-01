import type { ActivityType } from "./types";

/**
 * The three metric/UI shapes a cardio {@link ActivityType} falls into —
 * docs/cardio/51-cardio-overview-plan.md §1.1. Never persisted directly,
 * always derived via {@link activityFamilyOf}. Mirrors the mobile
 * `ActivityFamily` enum (`activity_type.dart`) and the backend
 * `com.lifey.workout.session.cardio.ActivityFamily`.
 */
export type ActivityFamily = "DISTANCE" | "MACHINE" | "GAME";

/** Throws on an unrecognized code — callers must only pass a real {@link ActivityType}. */
export function activityFamilyOf(activityType: ActivityType): ActivityFamily {
  switch (activityType) {
    case "RUNNING":
    case "WALKING":
    case "HIKING":
    case "CYCLING":
      return "DISTANCE";
    case "INDOOR_BIKE":
      return "MACHINE";
    case "BASKETBALL":
    case "FOOTBALL":
    case "OTHER_CARDIO":
      return "GAME";
  }
}

/**
 * Material Symbols icon name for a cardio activity type code, or for the
 * `'STRENGTH'` sentinel — matches `design/Lifey Cardio Design.dc.html` W01
 * exactly, same mapping as the mobile `activityTypeIcon`.
 */
export function activityTypeIcon(code: ActivityType | "STRENGTH" | null | undefined): string {
  switch (code) {
    case "RUNNING": return "directions_run";
    case "WALKING": return "directions_walk";
    case "HIKING": return "hiking";
    case "CYCLING": return "directions_bike";
    case "INDOOR_BIKE": return "pedal_bike";
    case "BASKETBALL": return "sports_basketball";
    case "FOOTBALL": return "sports_soccer";
    case "STRENGTH": return "fitness_center";
    default: return "bolt";
  }
}

/**
 * Accent color CSS variable for a cardio activity type code, or for
 * `'STRENGTH'` — the same metric-color tokens the mobile chip resolves via
 * `context.metricColors`/`colorScheme`, but here the token *is* the
 * light/dark switch (globals.css redefines each `--metric-*`/`--tertiary`
 * var per theme), so there's no explicit branch to write.
 */
export function activityTypeColor(code: ActivityType | "STRENGTH" | null | undefined): string {
  switch (code) {
    case "RUNNING": return "var(--m-kcal)";
    case "WALKING": return "var(--m-steps)";
    case "HIKING": return "var(--primary)";
    // Same as mobile (docs/cardio/62-cardio-cycling-plan.md §3): every metric
    // colour is already claimed, so outdoor cycling takes the warm secondary.
    case "CYCLING": return "var(--role)";
    case "INDOOR_BIKE": return "var(--m-carbs)";
    case "BASKETBALL": return "var(--m-fat)";
    case "FOOTBALL": return "var(--m-water)";
    case "STRENGTH": return "var(--m-weight)";
    default: return "var(--text-2)";
  }
}
