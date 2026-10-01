import { describe, expect, it } from "vitest";
import { matchesTypeFilter, parseWorkoutsTab, workoutsTabHref } from "./workoutsTab";

describe("parseWorkoutsTab", () => {
  it("accepts the three tabs", () => {
    expect(parseWorkoutsTab("sessions")).toBe("sessions");
    expect(parseWorkoutsTab("templates")).toBe("templates");
    expect(parseWorkoutsTab("exercises")).toBe("exercises");
  });

  it("falls back to sessions for missing, empty or unknown values", () => {
    expect(parseWorkoutsTab(null)).toBe("sessions");
    expect(parseWorkoutsTab(undefined)).toBe("sessions");
    expect(parseWorkoutsTab("")).toBe("sessions");
    expect(parseWorkoutsTab("Templates")).toBe("sessions");
    expect(parseWorkoutsTab("meals")).toBe("sessions");
  });
});

describe("workoutsTabHref", () => {
  it("sessions is the bare route; the others carry ?tab=", () => {
    expect(workoutsTabHref("sessions")).toBe("/workouts");
    expect(workoutsTabHref("templates")).toBe("/workouts?tab=templates");
    expect(workoutsTabHref("exercises")).toBe("/workouts?tab=exercises");
  });

  it("round-trips through parseWorkoutsTab", () => {
    for (const tab of ["sessions", "templates", "exercises"] as const) {
      const q = new URL(workoutsTabHref(tab), "http://x").searchParams.get("tab");
      expect(parseWorkoutsTab(q)).toBe(tab);
    }
  });
});

describe("matchesTypeFilter", () => {
  it("all shows everything", () => {
    expect(matchesTypeFilter("STRENGTH", "all")).toBe(true);
    expect(matchesTypeFilter("CARDIO", "all")).toBe(true);
  });

  it("strength is everything that is not cardio (old sessions have no kind)", () => {
    expect(matchesTypeFilter("STRENGTH", "strength")).toBe(true);
    expect(matchesTypeFilter(undefined, "strength")).toBe(true);
    expect(matchesTypeFilter("CARDIO", "strength")).toBe(false);
  });

  it("cardio is only cardio", () => {
    expect(matchesTypeFilter("CARDIO", "cardio")).toBe(true);
    expect(matchesTypeFilter("STRENGTH", "cardio")).toBe(false);
    expect(matchesTypeFilter(null, "cardio")).toBe(false);
  });
});
