import { describe, it, expect } from "vitest";
import { isValidGoalInput, parseGoalInput, goalToInput } from "./nutritionGoalsEditor";

describe("isValidGoalInput", () => {
  it("accepts an empty string (clears the goal)", () => {
    expect(isValidGoalInput("")).toBe(true);
    expect(isValidGoalInput("   ")).toBe(true);
  });

  it("accepts a non-negative integer", () => {
    expect(isValidGoalInput("2200")).toBe(true);
    expect(isValidGoalInput("0")).toBe(true);
  });

  it("rejects a negative number", () => {
    expect(isValidGoalInput("-100")).toBe(false);
  });

  it("rejects a decimal", () => {
    expect(isValidGoalInput("150.5")).toBe(false);
  });

  it("rejects non-numeric input", () => {
    expect(isValidGoalInput("abc")).toBe(false);
  });
});

describe("parseGoalInput", () => {
  it("returns null for an empty/blank string", () => {
    expect(parseGoalInput("")).toBeNull();
    expect(parseGoalInput("   ")).toBeNull();
  });

  it("parses a valid integer string", () => {
    expect(parseGoalInput("2200")).toBe(2200);
  });
});

describe("goalToInput", () => {
  it("renders null/undefined as an empty string", () => {
    expect(goalToInput(null)).toBe("");
    expect(goalToInput(undefined)).toBe("");
  });

  it("renders a number as its string form", () => {
    expect(goalToInput(2200)).toBe("2200");
  });
});
