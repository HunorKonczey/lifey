import { describe, expect, it } from "vitest";
import { buildPeriodStats, buildSlots, calorieVerdict, deltaTone, weightScale, type StatsGoals } from "./periodStats";
import { periodRange } from "./period";
import type { RawData } from "./types";
import type { MealResponse } from "@/features/nutrition/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

const d = (y: number, m: number, day: number) => new Date(y, m - 1, day);
const iso = (y: number, m: number, day: number) => `${y}-${String(m).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
const GOALS: StatsGoals = { calories: 1900, steps: 9000, weightKg: 65 };
const NOW = new Date(2026, 8, 27, 18, 0); // Sunday 27 Sep 2026, the last day of the canvas week
const EMPTY: RawData = { meals: [], weights: [], water: [], steps: [], sessions: [] };

let nextId = 1;

function meal(y: number, m: number, day: number, calories: number): MealResponse {
  return {
    id: nextId++,
    dateTime: new Date(y, m - 1, day, 12).toISOString(),
    mealType: "LUNCH",
    name: null,
    entries: [{ foodId: 1, foodName: "x", quantityInGrams: 100, calories, protein: 0, carbs: 0, fat: 0 }],
  };
}

function session(y: number, m: number, day: number, over: Partial<WorkoutSessionResponse> = {}): WorkoutSessionResponse {
  return {
    id: nextId++,
    startedAt: new Date(y, m - 1, day, 10).toISOString(),
    finishedAt: null,
    exercises: [],
    sets: [],
    activeCalories: null,
    averageHeartRate: null,
    healthWorkoutId: null,
    templateId: null,
    templateName: null,
    rpe: null,
    feedbackNote: null,
    trainerComment: null,
    trainerCommentAt: null,
    sessionKind: "STRENGTH",
    activityType: null,
    movingSeconds: null,
    cardio: null,
    splits: [],
    waypoints: [],
    ...over,
  };
}

const lift = (y: number, m: number, day: number, kg: number): WorkoutSessionResponse =>
  session(y, m, day, {
    sets: [{ exerciseId: 1, exerciseName: "Bench", reps: 10, weight: kg / 10, performedAt: new Date(y, m - 1, day, 10, 5).toISOString() }],
  });

const run = (y: number, m: number, day: number, meters: number | null, type: WorkoutSessionResponse["activityType"] = "RUNNING") =>
  session(y, m, day, {
    sessionKind: "CARDIO",
    activityType: type,
    cardio: meters == null ? null : ({ distanceMeters: meters } as WorkoutSessionResponse["cardio"]),
  });

const week = (raw: RawData, now = NOW) => buildPeriodStats({ raw, period: "week", start: d(2026, 9, 21), now, goals: GOALS });

describe("slots", () => {
  it("a week is seven days and flags the one holding today", () => {
    const slots = buildSlots("week", periodRange("week", d(2026, 9, 21)), NOW);
    expect(slots).toHaveLength(7);
    expect(slots.map((s) => s.isCurrent)).toEqual([false, false, false, false, false, false, true]);
  });

  it("days after today are future", () => {
    const slots = buildSlots("week", periodRange("week", d(2026, 9, 21)), new Date(2026, 8, 23, 9));
    expect(slots.map((s) => s.isFuture)).toEqual([false, false, false, true, true, true, true]);
  });

  it("a year is calendar weeks, the first and last clipped to the year", () => {
    const slots = buildSlots("year", periodRange("year", d(2026, 1, 1)), NOW);
    expect(slots[0].start).toEqual(d(2026, 1, 1)); // 1 Jan 2026 is a Thursday, its Monday is in 2025
    expect(slots[0].end).toEqual(d(2026, 1, 4));
    expect(slots[slots.length - 1].end).toEqual(d(2026, 12, 31));
    expect(slots).toHaveLength(53);
  });
});

describe("calories", () => {
  const raw: RawData = {
    ...EMPTY,
    meals: [
      meal(2026, 9, 21, 1780),
      meal(2026, 9, 22, 1920),
      meal(2026, 9, 23, 1690),
      meal(2026, 9, 25, 1850),
      meal(2026, 9, 27, 1041), // today, half logged
    ],
  };

  it("a day without a meal is null, never 0", () => {
    expect(week(raw).calories.values).toEqual([1780, 1920, 1690, null, 1850, null, 1041]);
  });

  it("the average leaves today's partial day out", () => {
    const s = week(raw);
    expect(s.calories.average).toBeCloseTo((1780 + 1920 + 1690 + 1850) / 4);
    expect(s.calories.loggedDays).toBe(4);
  });

  it("a finished week averages every logged day", () => {
    const s = week(raw, new Date(2026, 9, 5));
    expect(s.calories.average).toBeCloseTo((1780 + 1920 + 1690 + 1850 + 1041) / 5);
  });

  it("the delta is against the goal, green within 10 %", () => {
    const { delta } = week(raw).kpis.calories;
    expect(delta?.amount).toBeCloseTo(1810 - 1900);
    expect(delta?.tone).toBe("good");
  });

  it("an average far from the goal is worse, in either direction", () => {
    expect(calorieVerdict(1500, 1900)).toBe("under");
    expect(calorieVerdict(2200, 1900)).toBe("over");
    expect(calorieVerdict(1830, 1900)).toBe("onTarget");
  });

  it("with no goal the delta is against the previous week and neutral", () => {
    const s = buildPeriodStats({
      raw: { ...EMPTY, meals: [meal(2026, 9, 14, 2000), meal(2026, 9, 21, 1800)] },
      period: "week",
      start: d(2026, 9, 21),
      now: d(2026, 10, 5),
      goals: { ...GOALS, calories: null },
    });
    expect(s.kpis.calories.delta).toMatchObject({ amount: -200, tone: "neutral" });
  });

  it("nothing logged means no figure and no delta", () => {
    const s = week(EMPTY);
    expect(s.kpis.calories.value).toBeNull();
    expect(s.kpis.calories.delta).toBeNull();
  });
});

describe("year view", () => {
  const raw: RawData = { ...EMPTY, meals: [meal(2026, 8, 17, 1800), meal(2026, 8, 18, 1900), meal(2026, 8, 25, 1700)] };
  const year = buildPeriodStats({ raw, period: "year", start: d(2026, 1, 1), now: NOW, goals: GOALS });
  const aug17 = year.slots.findIndex((s) => s.start.getTime() === d(2026, 8, 17).getTime());

  it("shows weekly means of logged days", () => {
    expect(year.calories.values[aug17]).toBe(1850);
    expect(year.calories.values[aug17 + 1]).toBe(1700);
    expect(year.calories.values[0]).toBeNull();
  });

  it("knows where logging started, for the hatched band", () => {
    expect(year.calories.firstLog).toEqual(d(2026, 8, 17));
    expect(year.calories.emptySlotsBefore).toBe(aug17);
  });

  it("another year has no first-log date and no band", () => {
    for (const y of [2025, 2027]) {
      const other = buildPeriodStats({ raw, period: "year", start: d(y, 1, 1), now: NOW, goals: GOALS });
      expect(other.calories.firstLog).toBeNull();
      expect(other.calories.emptySlotsBefore).toBe(0);
    }
  });

  it("an empty previous year is no data, not a delta", () => {
    expect(year.calories.previousEmpty).toBe(true);
    expect(year.kpis.workouts.delta).toBeNull();
    expect(year.kpis.steps.delta).toBeNull();
  });
});

describe("weight", () => {
  it("the change needs two measurements", () => {
    expect(week({ ...EMPTY, weights: [{ id: 1, date: iso(2026, 9, 21), weight: 70 }] }).kpis.weight.value).toBeNull();
  });

  it("losing weight toward a lower goal is good; gaining is bad", () => {
    const losing = week({
      ...EMPTY,
      weights: [{ id: 1, date: iso(2026, 9, 21), weight: 70 }, { id: 2, date: iso(2026, 9, 26), weight: 69.6 }],
    });
    expect(losing.kpis.weight.value).toBeCloseTo(-0.4);
    expect(losing.kpis.weight.delta?.tone).toBe("good");
    const gaining = week({
      ...EMPTY,
      weights: [{ id: 1, date: iso(2026, 9, 21), weight: 69 }, { id: 2, date: iso(2026, 9, 26), weight: 69.5 }],
    });
    expect(gaining.kpis.weight.delta?.tone).toBe("bad");
  });

  it("without a goal weight the change is neutral", () => {
    const s = buildPeriodStats({
      raw: { ...EMPTY, weights: [{ id: 1, date: iso(2026, 9, 21), weight: 70 }, { id: 2, date: iso(2026, 9, 26), weight: 69 }] },
      period: "week",
      start: d(2026, 9, 21),
      now: NOW,
      goals: { ...GOALS, weightKg: null },
    });
    expect(s.kpis.weight.delta?.tone).toBe("neutral");
  });

  it("a missing day stays null in the series", () => {
    const s = week({ ...EMPTY, weights: [{ id: 1, date: iso(2026, 9, 21), weight: 70 }, { id: 2, date: iso(2026, 9, 24), weight: 69.5 }] });
    expect(s.weight.values).toEqual([70, null, null, 69.5, null, null, null]);
    expect(s.weight.latest).toBe(69.5);
  });

  it("a far goal stays off the scale and is flagged; a near one widens it", () => {
    expect(weightScale([69, 70.5], 65)).toEqual({ min: 68.5, max: 71.5 });
    const far = week({ ...EMPTY, weights: [{ id: 1, date: iso(2026, 9, 21), weight: 70.5 }, { id: 2, date: iso(2026, 9, 26), weight: 69 }] });
    expect(far.weight.goalOutsideScale).toBe(true);
    expect(weightScale([69, 70.5], 68.5)!.min).toBeLessThanOrEqual(68.5);
  });
});

describe("movement", () => {
  it("volume is a bar on workout days and a dot on finished rest days", () => {
    const raw: RawData = { ...EMPTY, sessions: [lift(2026, 9, 22, 7240), lift(2026, 9, 24, 5880)] };
    const s = week(raw, new Date(2026, 8, 25, 9));
    expect(s.volume.values).toEqual([null, 7240, null, 5880, null, null, null]);
    expect(s.volume.rest).toEqual([false, false, true, false, false, false, false]); // Mon precedes the first record; Fri is today, Sat and Sun are still to come
    expect(s.volume.total).toBe(13120);
  });

  it("a slot before anything was ever recorded is not a rest day", () => {
    const raw: RawData = { ...EMPTY, sessions: [lift(2026, 9, 24, 5880)] };
    const s = week(raw, new Date(2026, 8, 27, 9));
    expect(s.volume.rest).toEqual([false, false, false, false, true, true, false]); // Mon-Wed precede the first record, Thu has the workout, Fri and Sat are rest, Sun is today
  });

  it("cardio counts distance and machine families, not games, and leaves other days null", () => {
    const raw: RawData = {
      ...EMPTY,
      sessions: [run(2026, 9, 23, 14800), run(2026, 9, 25, 5200, "INDOOR_BIKE"), run(2026, 9, 25, 2000, "BASKETBALL"), run(2026, 9, 26, null)],
    };
    const s = week(raw);
    expect(s.cardio.values).toEqual([null, null, 14.8, null, 5.2, null, null]);
    expect(s.cardio.totalKm).toBe(20);
    expect(s.cardio.sessions).toBe(2); // the run and the bike; the game and the distance-less session do not count
  });

  it("steps: a zero count is no count, and today is out of the average", () => {
    const raw: RawData = {
      ...EMPTY,
      steps: [
        { date: iso(2026, 9, 21), steps: 12000 },
        { date: iso(2026, 9, 22), steps: 0 },
        { date: iso(2026, 9, 23), steps: 8000 },
        { date: iso(2026, 9, 27), steps: 6412 },
      ] as RawData["steps"],
    };
    const s = week(raw);
    expect(s.steps.values).toEqual([12000, null, 8000, null, null, null, 6412]);
    expect(s.steps.average).toBe(10000);
  });
});

describe("deltas", () => {
  it("a zero change is neutral", () => {
    expect(deltaTone(0, "higher")).toBe("neutral");
  });

  it("a steps decrease is worse, an increase better", () => {
    expect(deltaTone(-8, "higher")).toBe("bad");
    expect(deltaTone(3, "higher")).toBe("good");
  });

  it("a shortfall in a still-running sum is neutral, not bad", () => {
    expect(deltaTone(-2, "higher", { partial: true })).toBe("neutral");
    expect(deltaTone(1, "higher", { partial: true })).toBe("good");
  });

  it("running week: fewer workouts so far than last week is neutral; more is good", () => {
    const base = [lift(2026, 9, 14, 100), lift(2026, 9, 15, 100), lift(2026, 9, 17, 100), lift(2026, 9, 18, 100)];
    const fewer = week({ ...EMPTY, sessions: [...base, lift(2026, 9, 21, 100), lift(2026, 9, 22, 100)] });
    expect(fewer.kpis.workouts.delta).toMatchObject({ amount: -2, tone: "neutral" });
    const more = week({ ...EMPTY, sessions: [...base, ...[21, 22, 23, 24, 25].map((x) => lift(2026, 9, x, 100))] });
    expect(more.kpis.workouts.delta).toMatchObject({ amount: 1, tone: "good" });
    expect(more.kpis.workouts.previous).toBe(4);
  });

  it("a finished week's shortfall is bad, and the percentage comes with it", () => {
    const s = buildPeriodStats({
      raw: { ...EMPTY, sessions: [lift(2026, 9, 14, 1000), lift(2026, 9, 22, 500)] },
      period: "week",
      start: d(2026, 9, 21),
      now: d(2026, 10, 5),
      goals: GOALS,
    });
    expect(s.kpis.volume.delta).toMatchObject({ amount: -500, percent: -0.5, tone: "bad" });
  });

  it("no counterpart in the previous period means no delta", () => {
    const s = week({ ...EMPTY, sessions: [lift(2026, 9, 22, 500)] });
    expect(s.kpis.volume.delta).toBeNull();
    expect(s.kpis.volume.previous).toBeNull();
  });
});
