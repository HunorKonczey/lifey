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
