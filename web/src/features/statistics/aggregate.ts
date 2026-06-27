import { format, eachDayOfInterval } from "date-fns";
import type { MealResponse } from "@/features/nutrition/types";
import type { WeightResponse } from "@/features/weight/types";
import type { WaterEntryResponse } from "@/features/water/types";
import type { DailyStepCountResponse } from "@/features/steps/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

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

export interface AggregatedStats {
  caloriesSeries: SeriesPoint[];
  proteinSeries: SeriesPoint[];
  weightSeries: SeriesPoint[];
  waterSeries: SeriesPoint[];
  stepsSeries: SeriesPoint[];
  volumeSeries: SeriesPoint[];
  // KPIs over the window
  avgCalories: number;
  workoutCount: number;
  weightChange: number | null; // last − first in window
  latestWeight: number | null;
  totalVolume: number;
}

const dayKey = (d: Date | string) => format(new Date(d), "yyyy-MM-dd");

/** Aggregate raw data into daily series + KPIs over [start, end] (inclusive). */
export function aggregate(raw: RawData, start: Date, end: Date, label = "MMM d"): AggregatedStats {
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

  for (const s of raw.sessions) {
    for (const set of s.sets) {
      if (!inRange(set.performedAt)) continue;
      const k = dayKey(set.performedAt);
      vol.set(k, (vol.get(k) ?? 0) + set.weight * set.reps);
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

  // KPIs
  const calDays = caloriesSeries.filter((p) => p.value > 0);
  const avgCalories = calDays.length ? Math.round(calDays.reduce((s, p) => s + p.value, 0) / calDays.length) : 0;
  const workoutCount = raw.sessions.filter((s) => inRange(s.startedAt)).length;
  const totalVolume = Array.from(vol.values()).reduce((s, v) => s + v, 0);

  const weightPoints = weightSeries.map((p) => p.value);
  const weightChange = weightPoints.length >= 2 ? weightPoints[weightPoints.length - 1] - weightPoints[0] : null;
  const latestWeight = weightPoints.length ? weightPoints[weightPoints.length - 1] : null;

  return {
    caloriesSeries, proteinSeries, weightSeries, waterSeries, stepsSeries, volumeSeries,
    avgCalories, workoutCount, weightChange, latestWeight, totalVolume,
  };
}
