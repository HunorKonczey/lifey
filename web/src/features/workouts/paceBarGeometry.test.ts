import { describe, it, expect } from "vitest";
import { PaceBarGeometry, type PaceBar } from "./paceBarGeometry";

function bar(durationSeconds: number, partial = false): PaceBar {
  return { durationSeconds, label: `${durationSeconds}s`, partial };
}

describe("PaceBarGeometry — taller = faster", () => {
  it("gives the fastest split the tallest bar and the slowest the shortest", () => {
    const bars = [bar(300), bar(200), bar(400)]; // 200s is fastest
    const geometry = new PaceBarGeometry(bars, 300, 150);
    const fastest = geometry.barRect(1).height;
    const slowest = geometry.barRect(2).height;
    const middle = geometry.barRect(0).height;
    expect(fastest).toBeGreaterThan(middle);
    expect(middle).toBeGreaterThan(slowest);
  });

  it("lands every bar at the same mid-height when all splits are identical", () => {
    const bars = [bar(300), bar(300), bar(300)];
    const geometry = new PaceBarGeometry(bars, 300, 150);
    const heights = [0, 1, 2].map((i) => geometry.barRect(i).height);
    expect(heights[0]).toBeCloseTo(heights[1]);
    expect(heights[1]).toBeCloseTo(heights[2]);
    // 0.72 fraction of the 134px plot height (150 - 16 label band).
    expect(heights[0]).toBeCloseTo((150 - 16) * 0.72, 1);
  });
});

describe("PaceBarGeometry — the partial tail stays out of the evaluation", () => {
  it("excludes a partial bar from slowest/fastest even if it's numerically extreme", () => {
    // The partial tail is very short (60s) — without exclusion it would be
    // "fastest" by duration, which is meaningless for a sub-km remainder.
    const bars = [bar(300), bar(280), bar(60, true)];
    const geometry = new PaceBarGeometry(bars, 300, 150);
    expect(geometry.fastestSeconds).toBe(280);
    expect(geometry.slowestSeconds).toBe(300);
  });

  it("never assigns the partial tail the fastest-split label", () => {
    const bars = [bar(300), bar(280), bar(60, true)];
    const geometry = new PaceBarGeometry(bars, 300, 150);
    expect(geometry.fastestIndex).toBe(1);
  });

  it("draws the partial bar at a fixed, flat height regardless of its own duration", () => {
    const bars = [bar(300), bar(280), bar(1, true)]; // absurdly "fast" duration
    const geometry = new PaceBarGeometry(bars, 300, 150);
    const plotHeight = 150 - 16;
    expect(geometry.barRect(2).height).toBeCloseTo(plotHeight * 0.22, 5);
  });

  it("excludes the partial tail from the average line", () => {
    const withPartial = new PaceBarGeometry([bar(300), bar(280), bar(1, true)], 300, 150);
    const withoutPartial = new PaceBarGeometry([bar(300), bar(280)], 300, 150);
    expect(withPartial.averageLineY).toBeCloseTo(withoutPartial.averageLineY!, 5);
  });

  it("returns null slowest/fastest/average when every bar is partial", () => {
    const geometry = new PaceBarGeometry([bar(60, true)], 100, 150);
    expect(geometry.slowestSeconds).toBeNull();
    expect(geometry.fastestSeconds).toBeNull();
    expect(geometry.fastestIndex).toBeNull();
    expect(geometry.averageLineY).toBeNull();
  });
});

describe("PaceBarGeometry — fastestIndex ties", () => {
  it("keeps the first index on a tie for fastest", () => {
    const bars = [bar(200), bar(300), bar(200)];
    const geometry = new PaceBarGeometry(bars, 300, 150);
    expect(geometry.fastestIndex).toBe(0);
  });
});

describe("PaceBarGeometry — bar width", () => {
  it("uses the wide bar under 15 splits", () => {
    const bars = Array.from({ length: 5 }, () => bar(300));
    const geometry = new PaceBarGeometry(bars, 500, 150);
    expect(geometry.barWidth).toBe(26);
  });

  it("switches to the dense bar at 15+ splits", () => {
    const bars = Array.from({ length: 15 }, () => bar(300));
    const geometry = new PaceBarGeometry(bars, 500, 150);
    expect(geometry.barWidth).toBe(14);
  });

  it("shrinks further than the dense width when slots are too narrow", () => {
    const bars = Array.from({ length: 50 }, () => bar(300));
    const geometry = new PaceBarGeometry(bars, 200, 150); // 4px slots
    expect(geometry.barWidth).toBe(4);
  });
});

describe("PaceBarGeometry — indexAt (tap/click hit-testing)", () => {
  it("maps an x coordinate to the slot it falls in", () => {
    const bars = [bar(300), bar(300), bar(300)];
    const geometry = new PaceBarGeometry(bars, 300, 150); // 100px slots
    expect(geometry.indexAt(50)).toBe(0);
    expect(geometry.indexAt(150)).toBe(1);
    expect(geometry.indexAt(250)).toBe(2);
  });

  it("returns null outside the chart's bounds", () => {
    const bars = [bar(300)];
    const geometry = new PaceBarGeometry(bars, 100, 150);
    expect(geometry.indexAt(-5)).toBeNull();
    expect(geometry.indexAt(200)).toBeNull();
  });

  it("returns null for an empty chart", () => {
    expect(new PaceBarGeometry([], 100, 150).indexAt(50)).toBeNull();
  });
});
