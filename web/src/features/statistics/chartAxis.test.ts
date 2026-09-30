import { describe, expect, it } from "vitest";
import { createFormat } from "@/lib/format/lifeyFormat";
import { axisColumns } from "./chartAxis";
import { periodRange } from "./period";
import { buildSlots } from "./periodStats";

const hu = createFormat("hu");
const en = createFormat("en");
const d = (y: number, m: number, day: number) => new Date(y, m - 1, day);
const NOW = new Date(2026, 8, 27, 18);

describe("axisColumns", () => {
  it("week: weekday names with today as Ma", () => {
    const slots = buildSlots("week", periodRange("week", d(2026, 9, 21)), NOW);
    const cols = axisColumns("week", slots, hu, "Ma");
    expect(cols.map((c) => c.axisLabel)).toEqual(["H", "K", "Sze", "Cs", "P", "Szo", "Ma"]);
    expect(cols[6].isToday).toBe(true);
    expect(new Set(cols.map((c) => c.key)).size).toBe(7);
  });

  it("month: the 1st as a date, every fifth day a number, the rest empty", () => {
    const slots = buildSlots("month", periodRange("month", d(2026, 9, 1)), d(2026, 10, 15));
    const labels = axisColumns("month", slots, hu, "Ma").map((c) => c.axisLabel);
    expect(labels).toHaveLength(30);
    expect(labels.filter(Boolean)).toEqual(["szept. 1.", "5", "10", "15", "20", "25", "30"]);
  });

  it("year: one name per month over its first column", () => {
    const slots = buildSlots("year", periodRange("year", d(2026, 1, 1)), NOW);
    const named = axisColumns("year", slots, en, "Today").map((c) => c.axisLabel).filter(Boolean);
    expect(named).toEqual(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]);
    expect(axisColumns("year", slots, hu, "Ma").every((c) => !c.isToday)).toBe(true);
  });
});
