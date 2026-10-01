import { eachDayOfInterval, format, startOfDay, subDays } from "date-fns";
import { isHuLocale } from "@/lib/format/lifeyFormat";
import type { PeriodRange } from "./period";
import type { RawData } from "./types";

/**
 * The statistics export (W5.7, client-031): built entirely in the browser from the lists the page already holds —
 * there is no backend call. One CSV **per chosen data set**; the files are downloaded one after the other (a ZIP would
 * need a dependency for a rare action).
 *
 * The files are made to open in Excel and LibreOffice as they are:
 * - **UTF-8 with a BOM**, otherwise Excel reads Hungarian accents as mojibake;
 * - **`;` between fields and a decimal comma for Hungarian**, `,` and a decimal point for English — with `,` as the
 *   separator Hungarian Excel puts every row in one cell, and "69.6" would be read as a date or text;
 * - **ISO dates and 24-hour times** (`2026-09-21`, `07:15`) so the columns sort and parse in any locale;
 * - numbers are plain (no thousands grouping) — this is data, not display;
 * - a text that would start a formula (`=`, `+`, `-`, `@`) gets a leading apostrophe, so a food named "=1+1" cannot
 *   run anything when the file is opened.
 */

export const EXPORT_SETS = ["meals", "weight", "workouts", "waterSteps"] as const;
export type ExportSet = (typeof EXPORT_SETS)[number];

export type ExportPeriodChoice = "viewed" | "last30" | "all";

export interface ExportLabels {
  /** Column headers, in the UI language. */
  headers: Record<ExportSet, string[]>;
  mealType: (type: string) => string;
  activity: (type: string) => string;
  sessionKind: (kind: "STRENGTH" | "CARDIO") => string;
}

export interface CsvFile {
  set: ExportSet;
  name: string;
  /** The whole file, BOM included. */
  content: string;
}

const BOM = "﻿";
const EOL = "\r\n";
const ISO = "yyyy-MM-dd";

const day = (value: Date | string) => startOfDay(new Date(value));
const iso = (d: Date) => format(d, ISO);
const time = (value: string) => format(new Date(value), "HH:mm");

/** The span an export covers, inclusive on both ends. */
export function exportRange(choice: ExportPeriodChoice, viewed: PeriodRange, raw: RawData, now: Date): PeriodRange {
  const today = startOfDay(now);
  if (choice === "viewed") {
    // A period that is still running ends today: nothing after today can exist.
    return { start: viewed.start, end: viewed.end.getTime() > today.getTime() ? today : viewed.end };
  }
  if (choice === "last30") return { start: subDays(today, 29), end: today };
  const first = firstRecordedDay(raw);
  return { start: first ?? today, end: today };
}

function firstRecordedDay(raw: RawData): Date | null {
  const days: Date[] = [
    ...raw.meals.map((m) => day(m.dateTime)),
    ...raw.weights.map((w) => day(w.date)),
    ...raw.water.map((w) => day(w.consumedAt)),
    ...raw.steps.map((s) => day(s.date)),
    ...raw.sessions.map((s) => day(s.startedAt)),
  ];
  return days.length === 0 ? null : days.reduce((a, b) => (b.getTime() < a.getTime() ? b : a));
}

/**
 * `lifey-2026-09-21_27.csv` for one data set: the end of the range is shortened to what differs from the start
 * (the day inside a month, month-day inside a year). With several sets each file also carries its set name,
 * `lifey-2026-09-21_27-weight.csv`, so they stay apart in a downloads folder.
 */
export function exportFileName(range: PeriodRange, set: ExportSet | null): string {
  const from = iso(range.start);
  const to = iso(range.end);
  let shortTo = to;
  if (from.slice(0, 7) === to.slice(0, 7)) shortTo = to.slice(8);
  else if (from.slice(0, 4) === to.slice(0, 4)) shortTo = to.slice(5);
  const base = from === to ? `lifey-${from}` : `lifey-${from}_${shortTo}`;
  return set ? `${base}-${set}.csv` : `${base}.csv`;
}

/** A single CSV cell: quoted when it holds the separator, a quote or a line break. */
export function csvCell(value: string, separator: string): string {
  return /["\r\n]/.test(value) || value.includes(separator) ? `"${value.replace(/"/g, '""')}"` : value;
}

/** Free text from the user: defused against spreadsheet formulas. */
export function safeText(value: string | null | undefined): string {
  const text = value ?? "";
  return /^[=+\-@\t\r]/.test(text) ? `'${text}` : text;
}

/** A plain number for a spreadsheet: no grouping, the locale's decimal mark, at most `digits` decimals. */
export function csvNumber(value: number, digits: number, hu: boolean): string {
  const text = String(Number(value.toFixed(digits)));
  return hu ? text.replace(".", ",") : text;
}

const inside = (range: PeriodRange, value: Date | string) => {
  const d = day(value).getTime();
  return d >= range.start.getTime() && d <= range.end.getTime();
};

type Row = (string | number | null)[];

function mealRows(raw: RawData, range: PeriodRange, labels: ExportLabels, n: (v: number, d: number) => string): Row[] {
  const rows: { at: number; row: string[] }[] = [];
  for (const meal of raw.meals) {
    if (!inside(range, meal.dateTime)) continue;
    const at = new Date(meal.dateTime).getTime();
    for (const e of meal.entries) {
      rows.push({
        at,
        row: [
          iso(day(meal.dateTime)),
          time(meal.dateTime),
          labels.mealType(meal.mealType),
          safeText(e.foodName),
          n(e.quantityInGrams, 1),
          n(e.calories, 0),
          n(e.protein, 1),
          n(e.carbs, 1),
          n(e.fat, 1),
        ],
      });
    }
  }
  return rows.sort((a, b) => a.at - b.at).map((r) => r.row);
}

function weightRows(raw: RawData, range: PeriodRange, n: (v: number, d: number) => string): Row[] {
  return raw.weights
    .filter((w) => inside(range, w.date))
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((w) => [w.date, n(w.weight, 1)]);
}

function workoutRows(raw: RawData, range: PeriodRange, labels: ExportLabels, n: (v: number, d: number) => string): Row[] {
  const rows: { at: number; row: string[] }[] = [];
  for (const s of raw.sessions) {
    if (!inside(range, s.startedAt)) continue;
    const base = [iso(day(s.startedAt)), time(s.startedAt), labels.sessionKind(s.sessionKind)];
    if (s.sessionKind === "CARDIO") {
      const meters = s.cardio?.distanceMeters;
      rows.push({
        at: new Date(s.startedAt).getTime(),
        row: [
          ...base,
          s.activityType ? labels.activity(s.activityType) : "",
          "",
          "",
          "",
          "",
          meters == null ? "" : n(meters / 1000, 2),
          s.movingSeconds == null ? "" : n(s.movingSeconds / 60, 1),
        ],
      });
      continue;
    }
    for (const set of s.sets) {
      rows.push({
        at: new Date(set.performedAt).getTime(),
        row: [...base, "", safeText(set.exerciseName), n(set.reps, 0), n(set.weight, 2), n(set.weight * set.reps, 1), "", ""],
      });
    }
  }
  return rows.sort((a, b) => a.at - b.at).map((r) => r.row);
}

function waterStepsRows(raw: RawData, range: PeriodRange, n: (v: number, d: number) => string): Row[] {
  const water = new Map<string, number>();
  for (const w of raw.water) {
    if (!inside(range, w.consumedAt)) continue;
    const k = iso(day(w.consumedAt));
    water.set(k, (water.get(k) ?? 0) + w.volumeLiters);
  }
  const steps = new Map(raw.steps.filter((s) => inside(range, s.date)).map((s) => [s.date, s.steps]));
  return eachDayOfInterval({ start: range.start, end: range.end })
    .map(iso)
    .filter((k) => water.has(k) || steps.has(k))
    .map((k) => [k, water.has(k) ? n(water.get(k)!, 2) : "", steps.has(k) ? String(steps.get(k)) : ""]);
}

/** The CSV text (BOM included) of one data set over `range`. */
export function buildCsv(set: ExportSet, raw: RawData, range: PeriodRange, locale: string, labels: ExportLabels): string {
  const hu = isHuLocale(locale);
  const separator = hu ? ";" : ",";
  const n = (value: number, digits: number) => csvNumber(value, digits, hu);
  const rows: Row[] =
    set === "meals"
      ? mealRows(raw, range, labels, n)
      : set === "weight"
        ? weightRows(raw, range, n)
        : set === "workouts"
          ? workoutRows(raw, range, labels, n)
          : waterStepsRows(raw, range, n);
  const lines = [labels.headers[set], ...rows].map((row) => row.map((cell) => csvCell(String(cell ?? ""), separator)).join(separator));
  return BOM + lines.join(EOL) + EOL;
}

/** One file per chosen set, in the order the sets are listed in the popover. */
export function buildExport(sets: ExportSet[], raw: RawData, range: PeriodRange, locale: string, labels: ExportLabels): CsvFile[] {
  const ordered = EXPORT_SETS.filter((s) => sets.includes(s));
  return ordered.map((set) => ({
    set,
    name: exportFileName(range, ordered.length === 1 ? null : set),
    content: buildCsv(set, raw, range, locale, labels),
  }));
}

/** Saves `files` through the browser, one after the other (a burst of programmatic clicks can trip the "download multiple files" block). */
export async function downloadCsvFiles(files: CsvFile[], gapMs = 250): Promise<void> {
  for (let i = 0; i < files.length; i++) {
    const blob = new Blob([files[i].content], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = files[i].name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10_000);
    if (i < files.length - 1) await new Promise((r) => setTimeout(r, gapMs));
  }
}
