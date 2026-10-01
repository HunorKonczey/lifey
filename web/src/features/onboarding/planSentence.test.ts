import { describe, expect, it } from "vitest";
import { planSentence } from "./planSentence";

describe("planSentence", () => {
  it("reads a lower intake as a deficit with the gap", () => {
    expect(planSentence({ calories: 2000, tdee: 2500 })).toEqual({ kind: "deficit", gap: 500 });
  });
  it("reads a higher intake as a surplus", () => {
    expect(planSentence({ calories: 2800, tdee: 2500 })).toEqual({ kind: "surplus", gap: 300 });
  });
  it("treats a small gap as maintenance, both ways", () => {
    expect(planSentence({ calories: 2490, tdee: 2500 }).kind).toBe("maintain");
    expect(planSentence({ calories: 2525, tdee: 2500 }).kind).toBe("maintain");
    expect(planSentence({ calories: 2526, tdee: 2500 }).kind).toBe("surplus");
  });
  it("rounds fractional gaps", () => {
    expect(planSentence({ calories: 1999.6, tdee: 2500 })).toEqual({ kind: "deficit", gap: 500 });
  });
});
