import { describe, expect, it } from "vitest";
import { isValidStepGoalInput, parseStepGoalInput } from "./stepGoalEditor";

describe("isValidStepGoalInput", () => {
  it("accepts an empty field (it clears the goal) and a whole number above zero", () => {
    expect(isValidStepGoalInput("")).toBe(true);
    expect(isValidStepGoalInput("   ")).toBe(true);
    expect(isValidStepGoalInput("8000")).toBe(true);
    expect(isValidStepGoalInput(" 10000 ")).toBe(true);
  });

  it("refuses zero, which the backend refuses too, and anything that is not a whole number", () => {
    expect(isValidStepGoalInput("0")).toBe(false);
    expect(isValidStepGoalInput("000")).toBe(false);
    expect(isValidStepGoalInput("-5")).toBe(false);
    expect(isValidStepGoalInput("8.5")).toBe(false);
    expect(isValidStepGoalInput("10 000")).toBe(false);
    expect(isValidStepGoalInput("abc")).toBe(false);
  });
});

describe("parseStepGoalInput", () => {
  it("is null for an empty field and the number otherwise", () => {
    expect(parseStepGoalInput("")).toBeNull();
    expect(parseStepGoalInput("  ")).toBeNull();
    expect(parseStepGoalInput("9000")).toBe(9000);
    expect(parseStepGoalInput(" 9000 ")).toBe(9000);
  });
});
