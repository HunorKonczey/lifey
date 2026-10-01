import { describe, expect, it } from "vitest";
import { ringSweeps } from "./ProgressRing";

describe("ringSweeps", () => {
  it("is zero at 0%", () => {
    expect(ringSweeps(0)).toEqual({ lap: 0, overflow: 0 });
  });

  it("treats negative progress as 0", () => {
    expect(ringSweeps(-0.5)).toEqual({ lap: 0, overflow: 0 });
  });

  it("treats NaN as 0", () => {
    expect(ringSweeps(NaN)).toEqual({ lap: 0, overflow: 0 });
  });

  it("is a partial lap under 100%", () => {
    expect(ringSweeps(0.22)).toEqual({ lap: 0.22, overflow: 0 });
  });

  it("is exactly one full lap, no overflow, at 100%", () => {
    expect(ringSweeps(1)).toEqual({ lap: 1, overflow: 0 });
  });

  it("is a full lap plus a partial overflow lap past 100%", () => {
    const { lap, overflow } = ringSweeps(1.3);
    expect(lap).toBe(1);
    expect(overflow).toBeCloseTo(0.3);
  });

  it("caps the overflow lap at exactly one turn — never sweeps past 360° per arc", () => {
    const { lap, overflow } = ringSweeps(3);
    expect(lap).toBe(1);
    expect(overflow).toBe(1);
    // Two arcs, each capped at one full turn (360°) — never a single arc past it.
    expect(lap).toBeLessThanOrEqual(1);
    expect(overflow).toBeLessThanOrEqual(1);
  });

  it("caps the overflow lap at one turn even far past double the goal", () => {
    expect(ringSweeps(10)).toEqual({ lap: 1, overflow: 1 });
  });
});
