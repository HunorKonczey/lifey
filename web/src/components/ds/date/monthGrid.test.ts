import { describe, expect, it } from "vitest";
import { isFuture, isSameDay, monthGrid } from "./monthGrid";

describe("monthGrid", () => {
  it("is always 42 cells (6 weeks)", () => {
    expect(monthGrid(2026, 8).length).toBe(42); // September 2026
  });

  it("starts on a Monday", () => {
    const grid = monthGrid(2026, 8);
    expect(grid[0].date.getDay()).toBe(1); // Monday
  });

  it("September 2026 starts on a Tuesday, so the first Monday is Aug 31", () => {
    const grid = monthGrid(2026, 8);
    expect(grid[0].date.getFullYear()).toBe(2026);
    expect(grid[0].date.getMonth()).toBe(7); // August
    expect(grid[0].date.getDate()).toBe(31);
    expect(grid[0].inMonth).toBe(false);

    // Sep 1 2026 is the second cell.
    expect(grid[1].date.getMonth()).toBe(8);
    expect(grid[1].date.getDate()).toBe(1);
    expect(grid[1].inMonth).toBe(true);
  });

  it("a month that starts on Monday has no leading days from the previous month", () => {
    // June 2026 starts on a Monday.
    const grid = monthGrid(2026, 5);
    expect(grid[0].date.getMonth()).toBe(5);
    expect(grid[0].date.getDate()).toBe(1);
    expect(grid[0].inMonth).toBe(true);
  });

  it("fills trailing days from the next month", () => {
    const grid = monthGrid(2026, 8); // September has 30 days
    const last = grid[grid.length - 1];
    expect(last.date >= new Date(2026, 9, 1) || last.inMonth).toBe(true);
  });
});

describe("isSameDay", () => {
  it("ignores time of day", () => {
    expect(isSameDay(new Date(2026, 8, 27, 3, 0), new Date(2026, 8, 27, 23, 59))).toBe(true);
    expect(isSameDay(new Date(2026, 8, 27), new Date(2026, 8, 28))).toBe(false);
  });
});

describe("isFuture", () => {
  it("a later calendar day is future, regardless of time", () => {
    const today = new Date(2026, 8, 27, 23, 0);
    expect(isFuture(new Date(2026, 8, 28, 0, 1), today)).toBe(true);
    expect(isFuture(new Date(2026, 8, 27, 0, 0), today)).toBe(false);
    expect(isFuture(new Date(2026, 8, 26, 23, 59), today)).toBe(false);
  });
});
