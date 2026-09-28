import { describe, expect, it } from "vitest";
import { ratioBarFractions } from "./RatioBar";

describe("ratioBarFractions", () => {
  it("splits the whole bar by share when there's no total", () => {
    expect(ratioBarFractions([1, 1, 2])).toEqual([0.25, 0.25, 0.5]);
  });

  it("is entirely 0 when every value is 0", () => {
    expect(ratioBarFractions([0, 0])).toEqual([0, 0]);
  });

  it("treats NaN and negative values as 0", () => {
    expect(ratioBarFractions([NaN, -5, 10])).toEqual([0, 0, 1]);
  });

  it("divides by the total when the sum is under it, leaving budget unfilled", () => {
    // 40/500 protein-ish kcal, 150/500 carbs-ish kcal, against a 500 total —
    // the remaining 310/500 is the empty track (the budget left).
    expect(ratioBarFractions([40, 150], 500)).toEqual([0.08, 0.3]);
  });

  it("scales segments down together to fill the bar once the sum exceeds the total", () => {
    // Sum is 600 against a 500 total — falls back to dividing by the sum
    // itself so the segments still fill (not overflow) the bar, at the same
    // relative proportions to each other.
    expect(ratioBarFractions([200, 400], 500)).toEqual([1 / 3, 2 / 3]);
  });

  it("ignores a total of 0 or less, falling back to a 100% split", () => {
    expect(ratioBarFractions([1, 3], 0)).toEqual([0.25, 0.75]);
    expect(ratioBarFractions([1, 3], -10)).toEqual([0.25, 0.75]);
  });
});
