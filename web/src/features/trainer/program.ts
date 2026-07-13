import {
  addDays, addWeeks, differenceInCalendarWeeks, format, isBefore, isMonday,
  nextMonday as dateFnsNextMonday, startOfDay,
} from "date-fns";
import { DAYS_OF_WEEK, type DayOfWeek, type ProgramWorkoutRequest } from "./types";

export { DAYS_OF_WEEK };

export const MIN_WEEKS = 1;
export const MAX_WEEKS = 12;

export function findSlot(
  workouts: ProgramWorkoutRequest[],
  weekNumber: number,
  dayOfWeek: DayOfWeek,
): ProgramWorkoutRequest | undefined {
  return workouts.find((w) => w.weekNumber === weekNumber && w.dayOfWeek === dayOfWeek);
}

/** Upserts a slot — replaces whatever was at (weekNumber, dayOfWeek), if anything. */
export function setSlot(workouts: ProgramWorkoutRequest[], slot: ProgramWorkoutRequest): ProgramWorkoutRequest[] {
  const withoutExisting = workouts.filter((w) => !(w.weekNumber === slot.weekNumber && w.dayOfWeek === slot.dayOfWeek));
  return [...withoutExisting, slot];
}

export function clearSlot(
  workouts: ProgramWorkoutRequest[],
  weekNumber: number,
  dayOfWeek: DayOfWeek,
): ProgramWorkoutRequest[] {
  return workouts.filter((w) => !(w.weekNumber === weekNumber && w.dayOfWeek === dayOfWeek));
}

/** Copies every slot from `sourceWeek` onto `targetWeek`, overwriting whatever was already there. */
export function duplicateWeek(
  workouts: ProgramWorkoutRequest[],
  sourceWeek: number,
  targetWeek: number,
): ProgramWorkoutRequest[] {
  const sourceSlots = workouts.filter((w) => w.weekNumber === sourceWeek);
  const withoutTarget = workouts.filter((w) => w.weekNumber !== targetWeek);
  return [...withoutTarget, ...sourceSlots.map((w) => ({ ...w, weekNumber: targetWeek }))];
}

/** Copies `sourceWeek`'s slots onto every other week from 1..weeksCount. */
export function copyWeekToAll(
  workouts: ProgramWorkoutRequest[],
  sourceWeek: number,
  weeksCount: number,
): ProgramWorkoutRequest[] {
  let result = workouts;
  for (let week = 1; week <= weeksCount; week++) {
    if (week === sourceWeek) continue;
    result = duplicateWeek(result, sourceWeek, week);
  }
  return result;
}

/** Distinct days of week used across the grid — mirrors the backend's ProgramSummaryResponse.slotsPerWeek. */
export function slotsPerWeek(workouts: ProgramWorkoutRequest[]): number {
  return new Set(workouts.map((w) => w.dayOfWeek)).size;
}

export interface ProgramValidation {
  nameError: boolean;
  weeksCountError: boolean;
  noSlotsError: boolean;
  /* Week numbers used by a slot but beyond weeksCount — shouldn't happen via the grid UI itself, but
   * guards against a stale slot left over from shrinking weeksCount after slots were placed. */
  overflowWeeks: number[];
}

/** Client-side mirror of the server's InvalidProgramStructureException checks (docs/34). */
export function validateProgram(name: string, weeksCount: number, workouts: ProgramWorkoutRequest[]): ProgramValidation {
  const overflowWeeks = [...new Set(workouts.filter((w) => w.weekNumber > weeksCount).map((w) => w.weekNumber))].sort(
    (a, b) => a - b,
  );
  return {
    nameError: name.trim().length === 0,
    weeksCountError: weeksCount < MIN_WEEKS || weeksCount > MAX_WEEKS,
    noSlotsError: workouts.length === 0,
    overflowWeeks,
  };
}

export function isProgramValid(validation: ProgramValidation): boolean {
  return !validation.nameError && !validation.weeksCountError && !validation.noSlotsError && validation.overflowWeeks.length === 0;
}

/** Drops slots whose week number no longer fits — used when the trainer shrinks weeksCount. */
export function dropOverflowWeeks(workouts: ProgramWorkoutRequest[], weeksCount: number): ProgramWorkoutRequest[] {
  return workouts.filter((w) => w.weekNumber <= weeksCount);
}

// ─── Assignment date math (weeks are Mon-Sun; a run always starts on a Monday) ───

/** The Monday on/after `from` — `from` itself if it's already a Monday. */
export function nextOrSameMonday(from: Date): Date {
  const start = startOfDay(from);
  return isMonday(start) ? start : dateFnsNextMonday(start);
}

/** True for a "yyyy-MM-dd" string that is both a Monday and not before `today`. */
export function isValidProgramStartDate(dateIso: string, today: Date = new Date()): boolean {
  if (!dateIso) return false;
  const date = new Date(`${dateIso}T00:00:00`);
  return isMonday(date) && !isBefore(date, startOfDay(today));
}

/** `startDate + weeksCount weeks - 1 day` — the last day of the run, inclusive. */
export function programEndDate(startDateIso: string, weeksCount: number): string {
  const start = new Date(`${startDateIso}T00:00:00`);
  const end = addDays(addWeeks(start, weeksCount), -1);
  return format(end, "yyyy-MM-dd");
}

/** 1-based current week within the run, clamped to [1, weeksCount] — before the start date is "week 1", after the end date is the last week. */
export function currentWeekNumber(startDateIso: string, weeksCount: number, today: Date = new Date()): number {
  const start = new Date(`${startDateIso}T00:00:00`);
  const diffWeeks = differenceInCalendarWeeks(startOfDay(today), start, { weekStartsOn: 1 });
  return Math.min(weeksCount, Math.max(1, diffWeeks + 1));
}

/** Inverse of {@link programEndDate}: reconstructs weeksCount from a [startDate, endDate] pair. */
export function weeksBetween(startDateIso: string, endDateIso: string): number {
  const start = new Date(`${startDateIso}T00:00:00`);
  const end = new Date(`${endDateIso}T00:00:00`);
  const diffDays = Math.round((end.getTime() - start.getTime()) / (24 * 60 * 60 * 1000));
  return Math.max(1, Math.round((diffDays + 1) / 7));
}
