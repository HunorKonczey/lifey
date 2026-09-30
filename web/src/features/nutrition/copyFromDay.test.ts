import { describe, expect, it } from "vitest";
import { calendarDaysBetween, daysBefore, dayKey, loggedDayKeys, mealsOnDay, quickSourceDays, sourceChip } from "./copyFromDay";
import type { MealResponse } from "./types";

const meal = (id: number, date: Date): MealResponse => ({ id, dateTime: date.toISOString(), mealType: "LUNCH", name: null, entries: [] });

describe("quickSourceDays", () => {
  it("is the day before and the one before that, across a month boundary", () => {
    const [a, b] = quickSourceDays(new Date(2026, 9, 1));
    expect(dayKey(a)).toBe(dayKey(new Date(2026, 8, 30)));
    expect(dayKey(b)).toBe(dayKey(new Date(2026, 8, 29)));
  });

  it("does not drift over the DST change (steps dates, not 24 h)", () => {
    expect(dayKey(daysBefore(new Date(2026, 2, 30), 1))).toBe(dayKey(new Date(2026, 2, 29)));
    expect(dayKey(daysBefore(new Date(2026, 9, 26), 1))).toBe(dayKey(new Date(2026, 9, 25)));
  });
});

describe("mealsOnDay", () => {
  it("keeps only that day's meals, earliest first", () => {
    const day = new Date(2026, 8, 26);
    const list = [meal(1, new Date(2026, 8, 26, 19, 30)), meal(2, new Date(2026, 8, 25, 12)), meal(3, new Date(2026, 8, 26, 7, 15)), meal(4, new Date(2026, 8, 27, 7))];
    expect(mealsOnDay(list, day).map((m) => m.id)).toEqual([3, 1]);
  });

  it("is empty for a day with nothing logged", () => {
    expect(mealsOnDay([meal(1, new Date(2026, 8, 26, 8))], new Date(2026, 8, 20))).toEqual([]);
  });
});

describe("loggedDayKeys", () => {
  it("has one key per day with a meal", () => {
    const keys = loggedDayKeys([meal(1, new Date(2026, 8, 26, 8)), meal(2, new Date(2026, 8, 26, 19)), meal(3, new Date(2026, 8, 25, 12))]);
    expect(keys.size).toBe(2);
    expect(keys.has(dayKey(new Date(2026, 8, 25)))).toBe(true);
  });
});

describe("sourceChip", () => {
  const target = new Date(2026, 8, 27);
  it("maps yesterday and the day before to the two chips", () => {
    expect(sourceChip(new Date(2026, 8, 26), target)).toBe("first");
    expect(sourceChip(new Date(2026, 8, 25, 22), target)).toBe("second");
  });
  it("calls any other day, including the same day, 'other'", () => {
    expect(sourceChip(new Date(2026, 8, 20), target)).toBe("other");
    expect(sourceChip(target, target)).toBe("other");
  });
  it("counts whole calendar days", () => {
    expect(calendarDaysBetween(new Date(2026, 8, 26, 23, 59), new Date(2026, 8, 27, 0, 1))).toBe(1);
  });
});
