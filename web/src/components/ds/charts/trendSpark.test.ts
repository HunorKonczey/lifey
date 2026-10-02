import { describe, expect, it } from "vitest";
import { sparkPoints } from "./TrendSpark";

describe("sparkPoints", () => {
  it("spreads points evenly across the width, inside the padding", () => {
    const pts = sparkPoints([1, 2, 3], 72, 28);
    expect(pts.map(([x]) => x)).toEqual([2, 36, 70]);
  });

  it("inverts y: the smallest value is lowest on screen, the biggest highest", () => {
    const pts = sparkPoints([70, 69, 68], 72, 28);
    expect(pts[0][1]).toBe(2); // 70 = max → top padding
    expect(pts[2][1]).toBe(26); // 68 = min → height - padding
  });

  it("a flat series sits on the middle line — no divide by zero", () => {
    expect(sparkPoints([70, 70, 70], 72, 28).every(([, y]) => y === 14)).toBe(true);
  });

  it("an empty series has no points; a single value sits in the middle", () => {
    expect(sparkPoints([], 72, 28)).toEqual([]);
    expect(sparkPoints([5], 72, 28)).toEqual([[36, 14]]);
  });
});
