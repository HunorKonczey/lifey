import { format, eachDayOfInterval } from "date-fns";
import type { MealResponse } from "@/features/nutrition/types";
import type { WeightResponse } from "@/features/weight/types";
import type { WaterEntryResponse } from "@/features/water/types";
import type { DailyStepCountResponse } from "@/features/steps/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";
import { activityFamilyOf } from "@/features/workouts/activityType";

export interface SeriesPoint {
  date: string; // display label
  value: number;
}

export interface RawData {
  meals: MealResponse[];
  weights: WeightResponse[];
  water: WaterEntryResponse[];
  steps: DailyStepCountResponse[];
  sessions: WorkoutSessionResponse[];
}

/**
 * Re-scopes `workoutCount`/`totalVolume` to one kind (docs/cardio/56
 * D-C3.4) — a UI-level filter, not a change to what `workoutCount` *means*
 * (D-C3.1: it stays "every session" under "ALL"). Cardio-only series like
 * `cardioDistanceSeries` ignore this except to go empty under `STRENGTH`
 * (nothing to show — mirrors the mobile `stat_chart_data.dart` behavior).
 */
export const STAT_KIND_FILTERS = ["ALL", "STRENGTH", "CARDIO"] as const;
export type StatKindFilter = (typeof STAT_KIND_FILTERS)[number];

export interface AggregatedStats {
  caloriesSeries: SeriesPoint[];
  proteinSeries: SeriesPoint[];
  weightSeries: SeriesPoint[];
  waterSeries: SeriesPoint[];
  stepsSeries: SeriesPoint[];
  volumeSeries: SeriesPoint[];
  /** Sparse — a day with no cardio distance is omitted, never a 0.00 point (docs/cardio/56 D-C3.5). */
  cardioDistanceSeries: SeriesPoint[];
  // KPIs over the window
  avgCalories: number;
  workoutCount: number;
  /** Additive fajta-bontás (docs/cardio/56 D-C3.2) — always both counts, regardless of kindFilter. */
  strengthWorkoutCount: number;
  cardioWorkoutCount: number;
  weightChange: number | null; // last − first in window
  latestWeight: number | null;
  totalVolume: number;
  /** Σ cardioDistanceSeries — km, DISTANCE + MACHINE families only. */
  totalCardioDistanceKm: number;
}

const dayKey = (d: Date | string) => format(new Date(d), "yyyy-MM-dd");

const matchesKind = (s: WorkoutSessionResponse, filter: StatKindFilter) =>
  filter === "ALL" || s.sessionKind === filter;

/** Aggregate raw data into daily series + KPIs over [start, end] (inclusive). */
export function aggregate(
  raw: RawData,
  start: Date,
  end: Date,
  label = "MMM d",
  kindFilter: StatKindFilter = "ALL",
): AggregatedStats {
  const days = eachDayOfInterval({ start, end });
  const inRange = (d: Date | string) => {
    const t = new Date(d).getTime();
    return t >= start.getTime() && t <= end.getTime() + 86_399_999; // include end day
  };

  // Per-day buckets
  const cal = new Map<string, number>();
  const prot = new Map<string, number>();
  const wat = new Map<string, number>();
  const vol = new Map<string, number>();
  const cardioDist = new Map<string, number>();

  for (const m of raw.meals) {
    if (!inRange(m.dateTime)) continue;
    const k = dayKey(m.dateTime);
    const c = m.entries.reduce((s, e) => s + e.calories, 0);
    const p = m.entries.reduce((s, e) => s + e.protein, 0);
    cal.set(k, (cal.get(k) ?? 0) + c);
    prot.set(k, (prot.get(k) ?? 0) + p);
  }

  for (const w of raw.water) {
    if (!inRange(w.consumedAt)) continue;
    const k = dayKey(w.consumedAt);
    wat.set(k, (wat.get(k) ?? 0) + w.volumeLiters);
  }

  const sessionsInKind = raw.sessions.filter((s) => matchesKind(s, kindFilter));

  for (const s of sessionsInKind) {
    for (const set of s.sets) {
      if (!inRange(set.performedAt)) continue;
      const k = dayKey(set.performedAt);
      vol.set(k, (vol.get(k) ?? 0) + set.weight * set.reps);
    }
  }

  // Cardio distance — DISTANCE + MACHINE families only (docs/cardio/56 §3),
  // same definition as the mobile `cardioDistance` StatMetric. Empty under
  // `STRENGTH`: a cardio-only series has nothing to show once cardio itself
  // is filtered out, not a re-scoped "strength distance" (there's no such
  // thing).
  if (kindFilter !== "STRENGTH") {
    for (const s of raw.sessions) {
      if (s.sessionKind !== "CARDIO" || !s.activityType) continue;
      const family = activityFamilyOf(s.activityType);
      const distanceMeters = s.cardio?.distanceMeters;
      if ((family !== "DISTANCE" && family !== "MACHINE") || distanceMeters == null) continue;
      if (!inRange(s.startedAt)) continue;
      const k = dayKey(s.startedAt);
      cardioDist.set(k, (cardioDist.get(k) ?? 0) + distanceMeters / 1000);
    }
  }

  const stepByDate = new Map(raw.steps.map((s) => [s.date, s.steps]));
  const weightByDate = new Map(raw.weights.map((w) => [w.date, w.weight]));

  const mkSeries = (bucket: Map<string, number>, round = true): SeriesPoint[] =>
    days.map((d) => {
      const k = dayKey(d);
      const v = bucket.get(k) ?? 0;
      return { date: format(d, label), value: round ? Math.round(v) : Number(v.toFixed(2)) };
    });

  const caloriesSeries = mkSeries(cal);
  const proteinSeries = mkSeries(prot);
  const waterSeries = mkSeries(wat, false);
  const volumeSeries = mkSeries(vol);
  const stepsSeries: SeriesPoint[] = days.map((d) => ({
    date: format(d, label),
    value: stepByDate.get(dayKey(d)) ?? 0,
  }));

  // Weight: only actual logged points within range (sparse)
  const weightSeries: SeriesPoint[] = days
    .filter((d) => weightByDate.has(dayKey(d)))
    .map((d) => ({ date: format(d, label), value: weightByDate.get(dayKey(d))! }));

  // Cardio distance: only actual days with distance (sparse, D-C3.5 — a
  // dayless-of-running week is missing data, not a 0.00 km point).
  const cardioDistanceSeries: SeriesPoint[] = days
    .filter((d) => cardioDist.has(dayKey(d)))
    .map((d) => ({ date: format(d, label), value: Number(cardioDist.get(dayKey(d))!.toFixed(2)) }));

  // KPIs
  const calDays = caloriesSeries.filter((p) => p.value > 0);
  const avgCalories = calDays.length ? Math.round(calDays.reduce((s, p) => s + p.value, 0) / calDays.length) : 0;
  const workoutCount = sessionsInKind.filter((s) => inRange(s.startedAt)).length;
  // Additive breakdown (D-C3.2) — always both counts, over the full
  // unfiltered session list, independent of kindFilter.
  const strengthWorkoutCount = raw.sessions.filter((s) => s.sessionKind === "STRENGTH" && inRange(s.startedAt)).length;
  const cardioWorkoutCount = raw.sessions.filter((s) => s.sessionKind === "CARDIO" && inRange(s.startedAt)).length;
  const totalVolume = Array.from(vol.values()).reduce((s, v) => s + v, 0);
  const totalCardioDistanceKm = Number(Array.from(cardioDist.values()).reduce((s, v) => s + v, 0).toFixed(2));

  const weightPoints = weightSeries.map((p) => p.value);
  const weightChange = weightPoints.length >= 2 ? weightPoints[weightPoints.length - 1] - weightPoints[0] : null;
  const latestWeight = weightPoints.length ? weightPoints[weightPoints.length - 1] : null;

  return {
    caloriesSeries, proteinSeries, weightSeries, waterSeries, stepsSeries, volumeSeries, cardioDistanceSeries,
    avgCalories, workoutCount, strengthWorkoutCount, cardioWorkoutCount,
    weightChange, latestWeight, totalVolume, totalCardioDistanceKm,
  };
}
