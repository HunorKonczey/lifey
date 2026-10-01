import { describe, expect, it } from "vitest";
import { passwordStrength } from "./passwordStrength";

describe("passwordStrength", () => {
  it("is empty for nothing and weak below 8 characters", () => {
    expect(passwordStrength("")).toBe(0);
    expect(passwordStrength("Ab1!")).toBe(1);
    expect(passwordStrength("Abcdef1")).toBe(1);
  });

  it("an 8-character password is at least acceptable, more with variety and length", () => {
    expect(passwordStrength("abcdefgh")).toBe(2);
    expect(passwordStrength("abcdefg1")).toBe(2);
    expect(passwordStrength("Abcdefg1")).toBe(3);
    expect(passwordStrength("Abcdefg1!")).toBe(4);
    expect(passwordStrength("abcdefghijkl")).toBe(2);
    expect(passwordStrength("abcdefghijk1")).toBe(3);
  });

  it("never exceeds four segments", () => {
    expect(passwordStrength("Correct-Horse-Battery-9")).toBe(4);
  });
});
