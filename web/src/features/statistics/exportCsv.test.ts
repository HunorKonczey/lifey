import { describe, expect, it } from "vitest";
import { buildCsv, buildExport, csvCell, csvNumber, exportFileName, exportRange, safeText, type ExportLabels } from "./exportCsv";
import type { RawData } from "./types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

const d = (y: number, m: number, day: number) => new Date(y, m - 1, day);
const WEEK = { start: d(2026, 9, 21), end: d(2026, 9, 27) };

const LABELS: ExportLabels = {
  headers: {
    meals: ["Dátum", "Idő", "Étkezés", "Étel", "Mennyiség (g)", "kcal", "Fehérje (g)", "Szénhidrát (g)", "Zsír (g)", "Rost (g)", "Cukor (g)"],
    weight: ["Dátum", "Testsúly (kg)"],
    workouts: ["Dátum", "Idő", "Fajta", "Tevékenység", "Gyakorlat", "Ismétlés", "Súly (kg)", "Volumen (kg)", "Táv (km)", "Idő (perc)"],
    waterSteps: ["Dátum", "Víz (L)", "Lépés"],
  },
  mealType: (t) => ({ LUNCH: "Ebéd" })[t] ?? t,
  activity: (t) => ({ RUNNING: "Futás" })[t] ?? t,
  sessionKind: (k) => (k === "CARDIO" ? "Cardio" : "Erősítő"),
};

const EMPTY: RawData = { meals: [], weights: [], water: [], steps: [], sessions: [] };

const session = (over: Partial<WorkoutSessionResponse>): WorkoutSessionResponse => ({
  id: 1,
  startedAt: new Date(2026, 8, 22, 10).toISOString(),
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
});

describe("escaping", () => {
  it("quotes a cell holding the separator, a quote or a line break", () => {
    expect(csvCell("Túrós, tejfölös", ",")).toBe('"Túrós, tejfölös"');
    expect(csvCell("Túrós, tejfölös", ";")).toBe("Túrós, tejfölös");
    expect(csvCell('say "hi"', ";")).toBe('"say ""hi"""');
    expect(csvCell("a\nb", ";")).toBe('"a\nb"');
  });

  it("defuses a text that would start a formula", () => {
    expect(safeText("=1+1")).toBe("'=1+1");
    expect(safeText("@SUM(A1)")).toBe("'@SUM(A1)");
    expect(safeText("-2 napos")).toBe("'-2 napos");
    expect(safeText("Alma")).toBe("Alma");
  });

  it("numbers are plain and use the locale's decimal mark", () => {
    expect(csvNumber(1234.5, 1, false)).toBe("1234.5");
    expect(csvNumber(1234.5, 1, true)).toBe("1234,5");
    expect(csvNumber(69.6, 1, true)).toBe("69,6");
    expect(csvNumber(70, 1, false)).toBe("70");
  });
});

describe("file names", () => {
  it("shortens the end of the range to what differs", () => {
    expect(exportFileName(WEEK, null)).toBe("lifey-2026-09-21_27.csv");
    expect(exportFileName({ start: d(2026, 9, 28), end: d(2026, 10, 4) }, null)).toBe("lifey-2026-09-28_10-04.csv");
    expect(exportFileName({ start: d(2025, 12, 30), end: d(2026, 1, 5) }, null)).toBe("lifey-2025-12-30_2026-01-05.csv");
  });

  it("a one-day range has no end and several sets carry their name", () => {
    expect(exportFileName({ start: d(2026, 9, 21), end: d(2026, 9, 21) }, null)).toBe("lifey-2026-09-21.csv");
    expect(exportFileName(WEEK, "weight")).toBe("lifey-2026-09-21_27-weight.csv");
  });
});

describe("ranges", () => {
  const NOW = new Date(2026, 8, 30, 12);
  const raw: RawData = { ...EMPTY, weights: [{ id: 1, date: "2026-08-17", weight: 70 }] };

  it("the viewed period stops at today when it is still running", () => {
    expect(exportRange("viewed", { start: d(2026, 9, 28), end: d(2026, 10, 4) }, raw, NOW)).toEqual({ start: d(2026, 9, 28), end: d(2026, 9, 30) });
    expect(exportRange("viewed", WEEK, raw, NOW)).toEqual(WEEK);
  });

  it("30 days is today and the 29 before it", () => {
    expect(exportRange("last30", WEEK, raw, NOW)).toEqual({ start: d(2026, 9, 1), end: d(2026, 9, 30) });
  });

  it("all data starts at the first recorded day", () => {
    expect(exportRange("all", WEEK, raw, NOW)).toEqual({ start: d(2026, 8, 17), end: d(2026, 9, 30) });
    expect(exportRange("all", WEEK, EMPTY, NOW)).toEqual({ start: d(2026, 9, 30), end: d(2026, 9, 30) });
  });
});

describe("buildCsv", () => {
  it("starts with a UTF-8 BOM and ends each line with CRLF", () => {
    const csv = buildCsv("weight", { ...EMPTY, weights: [{ id: 1, date: "2026-09-21", weight: 70 }] }, WEEK, "hu", LABELS);
    expect(csv.charCodeAt(0)).toBe(0xfeff);
    expect(csv).toBe("﻿Dátum;Testsúly (kg)\r\n2026-09-21;70\r\n");
  });

  it("Hungarian: ; between fields and a decimal comma; English: , and a point", () => {
    const weights = [{ id: 1, date: "2026-09-21", weight: 69.6 }];
    expect(buildCsv("weight", { ...EMPTY, weights }, WEEK, "hu", LABELS)).toContain("2026-09-21;69,6");
    expect(buildCsv("weight", { ...EMPTY, weights }, WEEK, "en", LABELS)).toContain("2026-09-21,69.6");
  });

  it("only the days inside the range are written", () => {
    const weights = [
      { id: 1, date: "2026-09-20", weight: 71 },
      { id: 2, date: "2026-09-27", weight: 70 },
      { id: 3, date: "2026-09-28", weight: 69 },
    ];
    const lines = buildCsv("weight", { ...EMPTY, weights }, WEEK, "en", LABELS).trim().split("\r\n");
    expect(lines).toHaveLength(2);
    expect(lines[1]).toBe("2026-09-27,70");
  });

  it("meals: one row per entry with the meal type in words and accents intact", () => {
    const raw: RawData = {
      ...EMPTY,
      meals: [
        {
          id: 1,
          dateTime: new Date(2026, 8, 22, 12, 30).toISOString(),
          mealType: "LUNCH",
          name: null,
          entries: [
            { foodId: 1, foodName: "Túró Rudi", quantityInGrams: 120, calories: 312, protein: 14.4, carbs: 20, fat: 18.25, fiber: 1.25, sugar: 12 },
            { foodId: 2, foodName: "=HYPERLINK(x)", quantityInGrams: 50, calories: 10, protein: 0, carbs: 2, fat: 0 },
          ],
        },
      ],
    };
    const lines = buildCsv("meals", raw, WEEK, "hu", LABELS).trim().split("\r\n");
    expect(lines[1]).toBe("2026-09-22;12:30;Ebéd;Túró Rudi;120;312;14,4;20;18,3;1,3;12");
    expect(lines[2]).toContain("'=HYPERLINK(x)");
    // A food with no fibre/sugar figure leaves those cells empty - not 0.
    expect(lines[2].endsWith(";0;;")).toBe(true);
  });

  it("workouts: a row per set, and a cardio session as one row with its distance", () => {
    const raw: RawData = {
      ...EMPTY,
      sessions: [
        session({ sets: [{ exerciseId: 1, exerciseName: "Fekvenyomás", reps: 8, weight: 62.5, performedAt: new Date(2026, 8, 22, 10, 5).toISOString() }] }),
        session({
          id: 2,
          startedAt: new Date(2026, 8, 24, 7).toISOString(),
          sessionKind: "CARDIO",
          activityType: "RUNNING",
          movingSeconds: 1800,
          cardio: { distanceMeters: 5200 } as WorkoutSessionResponse["cardio"],
        }),
      ],
    };
    const lines = buildCsv("workouts", raw, WEEK, "hu", LABELS).trim().split("\r\n");
    expect(lines[1]).toBe("2026-09-22;10:00;Erősítő;;Fekvenyomás;8;62,5;500;;");
    expect(lines[2]).toBe("2026-09-24;07:00;Cardio;Futás;;;;;5,2;30");
  });

  it("water and steps: a row per day that has either", () => {
    const raw: RawData = {
      ...EMPTY,
      water: [
        { id: 1, consumedAt: new Date(2026, 8, 22, 9).toISOString(), volumeLiters: 0.25, sourceId: null, sourceName: null },
        { id: 2, consumedAt: new Date(2026, 8, 22, 15).toISOString(), volumeLiters: 0.5, sourceId: null, sourceName: null },
      ],
      steps: [{ id: 1, date: "2026-09-23", steps: 8412 }],
    };
    const lines = buildCsv("waterSteps", raw, WEEK, "en", LABELS).trim().split("\r\n");
    expect(lines).toEqual(["Dátum,Víz (L),Lépés", "2026-09-22,0.75,", "2026-09-23,,8412"]);
  });
});

describe("buildExport", () => {
  it("one file per chosen set, in a fixed order, the single-set file keeping the plain name", () => {
    const raw: RawData = { ...EMPTY, weights: [{ id: 1, date: "2026-09-21", weight: 70 }] };
    expect(buildExport(["weight"], raw, WEEK, "hu", LABELS).map((f) => f.name)).toEqual(["lifey-2026-09-21_27.csv"]);
    const two = buildExport(["waterSteps", "meals"], raw, WEEK, "hu", LABELS);
    expect(two.map((f) => f.name)).toEqual(["lifey-2026-09-21_27-meals.csv", "lifey-2026-09-21_27-waterSteps.csv"]);
  });
});
