import { describe, expect, it } from "vitest";
import { firstStepsState, showFirstSteps } from "./firstSteps";

const none = { pinned: false, dismissed: false };

describe("firstStepsState", () => {
  it("a brand-new account: nothing done, fresh, not complete", () => {
    const s = firstStepsState({ hasGoal: false, hasMeal: false, hasWeight: false });
    expect(s.steps.map((x) => x.done)).toEqual([false, false, false]);
    expect(s.fresh).toBe(true);
    expect(s.complete).toBe(false);
  });

  it("each step completes independently — weight before the first meal is fine", () => {
    const s = firstStepsState({ hasGoal: false, hasMeal: false, hasWeight: true });
    expect(s.steps).toEqual([
      { id: "goals", done: false },
      { id: "meal", done: false },
      { id: "weight", done: true },
    ]);
  });

  it("fresh means neither a meal nor a weight — a goal alone keeps it fresh (the canvas shows goals done)", () => {
    expect(firstStepsState({ hasGoal: true, hasMeal: false, hasWeight: false }).fresh).toBe(true);
    expect(firstStepsState({ hasGoal: true, hasMeal: true, hasWeight: false }).fresh).toBe(false);
    expect(firstStepsState({ hasGoal: true, hasMeal: false, hasWeight: true }).fresh).toBe(false);
  });

  it("complete needs a meal and a weight; goals aren't required", () => {
    expect(firstStepsState({ hasGoal: false, hasMeal: true, hasWeight: true }).complete).toBe(true);
    expect(firstStepsState({ hasGoal: true, hasMeal: true, hasWeight: false }).complete).toBe(false);
  });
});

describe("showFirstSteps", () => {
  const fresh = firstStepsState({ hasGoal: true, hasMeal: false, hasWeight: false });
  const afterMeal = firstStepsState({ hasGoal: true, hasMeal: true, hasWeight: false });
  const done = firstStepsState({ hasGoal: true, hasMeal: true, hasWeight: true });

  it("shows for a fresh account", () => {
    expect(showFirstSteps(fresh, none)).toBe(true);
  });

  it("stays after the first meal if it was already showing, so the tick is visible", () => {
    expect(showFirstSteps(afterMeal, { pinned: true, dismissed: false })).toBe(true);
  });

  it("an established account that merely lacks a weight never sees it (the weight tile has its own empty state)", () => {
    expect(showFirstSteps(afterMeal, none)).toBe(false);
  });

  it("goes away once a meal and a weight both exist, even if pinned", () => {
    expect(showFirstSteps(done, { pinned: true, dismissed: false })).toBe(false);
  });

  it("dismissing always hides it", () => {
    expect(showFirstSteps(fresh, { pinned: true, dismissed: true })).toBe(false);
  });
});
