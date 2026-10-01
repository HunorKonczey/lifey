import { describe, expect, it } from "vitest";
import {
  canStepForward,
  isCurrentPeriod,
  parsePeriodState,
  periodRange,
  periodSearch,
  previousPeriod,
  shiftPeriod,
  switchPeriod,
} from "./period";

const d = (y: number, m: number, day: number) => new Date(y, m - 1, day);
const NOW = d(2026, 9, 30); // a Wednesday

describe("period ranges", () => {
  it("a week runs Monday to Sunday", () => {
    expect(periodRange("week", d(2026, 9, 23))).toEqual({ start: d(2026, 9, 21), end: d(2026, 9, 27) });
  });

  it("a month and a year cover their calendar span", () => {
    expect(periodRange("month", d(2026, 2, 10))).toEqual({ start: d(2026, 2, 1), end: d(2026, 2, 28) });
    expect(periodRange("year", d(2026, 6, 1))).toEqual({ start: d(2026, 1, 1), end: d(2026, 12, 31) });
  });

  it("steps across month and year edges", () => {
    expect(shiftPeriod("week", d(2026, 9, 28), 1)).toEqual(d(2026, 10, 5));
    expect(shiftPeriod("month", d(2026, 1, 1), -1)).toEqual(d(2025, 12, 1));
    expect(shiftPeriod("year", d(2026, 1, 1), -1)).toEqual(d(2025, 1, 1));
  });

  it("previous period is the one right before", () => {
    expect(previousPeriod("week", d(2026, 9, 21))).toEqual({ start: d(2026, 9, 14), end: d(2026, 9, 20) });
  });
});

describe("stepping", () => {
  it("stops at the current period", () => {
    expect(canStepForward("week", d(2026, 9, 28), NOW)).toBe(false);
    expect(canStepForward("week", d(2026, 9, 21), NOW)).toBe(true);
    expect(canStepForward("month", d(2026, 8, 1), NOW)).toBe(true);
    expect(canStepForward("year", d(2026, 1, 1), NOW)).toBe(false);
  });

  it("knows which period is current", () => {
    expect(isCurrentPeriod("week", d(2026, 9, 28), NOW)).toBe(true);
    expect(isCurrentPeriod("week", d(2026, 9, 21), NOW)).toBe(false);
  });
});

describe("URL state", () => {
  const parse = (q: string) => parsePeriodState(new URLSearchParams(q), NOW);

  it("defaults to the current week", () => {
    expect(parse("")).toEqual({ period: "week", start: d(2026, 9, 28) });
  });

  it("reads period and start, snapping start to the period's first day", () => {
    expect(parse("period=week&start=2026-09-23")).toEqual({ period: "week", start: d(2026, 9, 21) });
    expect(parse("period=month&start=2026-07-15")).toEqual({ period: "month", start: d(2026, 7, 1) });
  });

  it("falls back on garbage and never lands in the future", () => {
    expect(parse("period=decade&start=x")).toEqual({ period: "week", start: d(2026, 9, 28) });
    expect(parse("period=year&start=2031-01-01")).toEqual({ period: "year", start: d(2026, 1, 1) });
  });

  it("round-trips through the query string", () => {
    const state = { period: "month" as const, start: d(2026, 8, 1) };
    expect(parse(periodSearch(state))).toEqual(state);
    expect(periodSearch(state)).toBe("period=month&start=2026-08-01");
  });

  it("switching the view keeps the viewed time in view", () => {
    expect(switchPeriod({ period: "week", start: d(2026, 8, 31) }, "month", NOW)).toEqual({ period: "month", start: d(2026, 8, 1) });
    expect(switchPeriod({ period: "year", start: d(2025, 1, 1) }, "week", NOW).start).toEqual(d(2024, 12, 30));
  });
});
