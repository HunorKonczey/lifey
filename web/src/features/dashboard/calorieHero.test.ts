import { describe, expect, it } from "vitest";
import { heroState, macroRowState } from "./calorieHero";

describe("heroState", () => {
  it("under budget: the number is what's left, caption 'left'", () => {
    const s = heroState(1041, 1900);
    expect(s).toMatchObject({ mode: "remaining", number: 859, captionKey: "kcalLeft", showGoalLine: true });
    expect(s.ringProgress).toBeCloseTo(0.548, 3);
  });

  it("exactly on the goal counts as reached, not over", () => {
    expect(heroState(1900, 1900)).toMatchObject({ mode: "remaining", number: 0, ringProgress: 1 });
  });

  it("over budget: the number is the overage, the ring runs a second lap", () => {
    const s = heroState(2112, 1900);
    expect(s).toMatchObject({ mode: "over", number: 212, captionKey: "kcalOver", showGoalLine: true });
    expect(s.ringProgress).toBeGreaterThan(1);
  });

  it("no goal: empty ring, the number is what was eaten, no goal line", () => {
    expect(heroState(640, null)).toMatchObject({ mode: "noGoal", ringProgress: 0, number: 640, captionKey: "kcalEaten", showGoalLine: false });
    expect(heroState(640, undefined).mode).toBe("noGoal");
  });

  it("a goal of 0 is no goal (never divide by it)", () => {
    expect(heroState(100, 0)).toMatchObject({ mode: "noGoal", ringProgress: 0 });
  });

  it("rounds only for display", () => {
    expect(heroState(1040.6, 1900).number).toBe(859);
  });

  it("nothing eaten yet shows the whole goal", () => {
    expect(heroState(0, 1900)).toMatchObject({ mode: "remaining", number: 1900, ringProgress: 0 });
  });
});

describe("macroRowState", () => {
  it("with a goal: progress and grams left", () => {
    const s = macroRowState(68, 120);
    expect(s.hasGoal).toBe(true);
    expect(s.progress).toBeCloseTo(0.567, 3);
    expect(s).toMatchObject({ left: 52, over: 0 });
  });

  it("past the goal: grams over, none left", () => {
    expect(macroRowState(135, 120)).toMatchObject({ left: 0, over: 15 });
  });

  it("without a goal: value only — no bar, no left/over", () => {
    expect(macroRowState(68, null)).toEqual({ hasGoal: false, progress: 0, left: 0, over: 0 });
    expect(macroRowState(68, 0).hasGoal).toBe(false);
  });
});
