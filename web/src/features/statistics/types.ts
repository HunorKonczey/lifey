import type { MealResponse } from "@/features/nutrition/types";
import type { WeightResponse } from "@/features/weight/types";
import type { WaterEntryResponse } from "@/features/water/types";
import type { DailyStepCountResponse } from "@/features/steps/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

/** Every list the statistics page loads, as the API returned it. */
export interface RawData {
  meals: MealResponse[];
  weights: WeightResponse[];
  water: WaterEntryResponse[];
  steps: DailyStepCountResponse[];
  sessions: WorkoutSessionResponse[];
}

export interface StatisticsResponse {
  totalCalories: number | null;
  totalProtein: number | null;
  totalCarbs: number | null;
  totalFat: number | null;
  /** Fibre and sugars of the foods that have a figure (LIF-148); null when none has, which is not 0. */
  totalFiber?: number | null;
  totalSugar?: number | null;
  /** True when some logged food has no fibre/sugar figure, so the totals above are a lower bound. */
  fiberSugarPartial?: boolean;
  /** Unchanged meaning — every session, strength and cardio alike (docs/cardio/56 D-C3.1). */
  workoutCount: number | null;
  latestWeight: number | null;
  totalWater: number | null;
  /** Additive fajta-bontás (docs/cardio/56 D-C3.2) — never null, unlike the fields above. */
  strengthWorkoutCount: number;
  cardioWorkoutCount: number;
  movingMinutes: number;
  totalDistanceMeters: number;
  totalElevationGainMeters: number;
}

/**
 * The Mozgás section's filter (docs/cardio/56 D-C3.4, W5.5): which movement cards show. It never changes a number —
 * calories and weight sit outside it, and so do the KPI tiles.
 */
export const STAT_KIND_FILTERS = ["ALL", "STRENGTH", "CARDIO"] as const;
export type StatKindFilter = (typeof STAT_KIND_FILTERS)[number];
