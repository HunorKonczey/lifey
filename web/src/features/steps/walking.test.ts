import { describe, expect, it } from "vitest";
import { DEFAULT_DAILY_STEP_GOAL, effectiveDailyStepGoal, walkingMinutes } from "./walking";

describe("effectiveDailyStepGoal", () => {
  it("uses the user's goal when it is a positive number", () => {
    expect(effectiveDailyStepGoal({ dailyStepGoal: 9000 })).toBe(9000);
  });

  it("falls back to the 10 000 default for null, missing, zero and negative", () => {
    expect(effectiveDailyStepGoal({ dailyStepGoal: null })).toBe(DEFAULT_DAILY_STEP_GOAL);
    expect(effectiveDailyStepGoal({})).toBe(10_000);
    expect(effectiveDailyStepGoal(undefined)).toBe(10_000);
    expect(effectiveDailyStepGoal(null)).toBe(10_000);
    expect(effectiveDailyStepGoal({ dailyStepGoal: 0 })).toBe(10_000);
    expect(effectiveDailyStepGoal({ dailyStepGoal: -5 })).toBe(10_000);
  });
});

describe("walkingMinutes", () => {
  it("is steps at 100 a minute, rounded to 5: 2 588 steps is about 25 minutes", () => {
    expect(walkingMinutes(2588)).toBe(25);
    expect(walkingMinutes(5000)).toBe(50);
    expect(walkingMinutes(1250)).toBe(15); // 12.5 is halfway: rounds up
  });

  it("never says less than 5 minutes", () => {
    expect(walkingMinutes(40)).toBe(5);
    expect(walkingMinutes(0)).toBe(5);
  });
});
