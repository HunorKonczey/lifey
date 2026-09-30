import { describe, expect, it } from "vitest";
import {
  IDLE,
  adjustRest,
  isFinished,
  isUrgent,
  remainingFraction,
  remainingSeconds,
  restSecondsFor,
  skipRest,
  startRest,
  togglePause,
} from "./restTimer";

const T0 = 1_000_000;

describe("startRest / remainingSeconds", () => {
  it("counts down from the total, derived from the clock", () => {
    const s = startRest(T0, 120, 4);
    expect(remainingSeconds(s, T0)).toBe(120);
    expect(remainingSeconds(s, T0 + 48_000)).toBe(72);
    expect(remainingSeconds(s, T0 + 119_100)).toBe(1); // rounded up — "0:01" until the very end
    expect(remainingSeconds(s, T0 + 120_000)).toBe(0);
    expect(remainingSeconds(s, T0 + 500_000)).toBe(0); // never negative
  });

  it("survives a throttled tab: one late read gives the right number, no ticks needed", () => {
    const s = startRest(T0, 90, null);
    expect(remainingSeconds(s, T0 + 61_000)).toBe(29);
  });

  it("is finished at zero, and only while running", () => {
    const s = startRest(T0, 10, null);
    expect(isFinished(s, T0 + 9_999)).toBe(false);
    expect(isFinished(s, T0 + 10_000)).toBe(true);
    expect(isFinished(IDLE, T0)).toBe(false);
  });
});

describe("urgent last seconds", () => {
  const s = startRest(T0, 60, null);
  it("the last five seconds, not the zero and not before", () => {
    expect(isUrgent(s, T0 + 54_000)).toBe(false); // 6 s left
    expect(isUrgent(s, T0 + 55_000)).toBe(true); // 5 s left
    expect(isUrgent(s, T0 + 59_500)).toBe(true);
    expect(isUrgent(s, T0 + 60_000)).toBe(false); // done
  });

  it("a paused timer is not urgent", () => {
    const paused = togglePause(startRest(T0, 60, null), T0 + 57_000);
    expect(isUrgent(paused, T0 + 99_000)).toBe(false);
  });
});

describe("adjustRest (±15 s)", () => {
  it("+15 adds to what is left and to the total, so the bar does not jump past full", () => {
    const s = adjustRest(startRest(T0, 120, null), T0 + 105_000, 15); // 15 s left → 30
    expect(remainingSeconds(s, T0 + 105_000)).toBe(30);
    expect(remainingFraction(s, T0 + 105_000)).toBeLessThanOrEqual(1);
  });

  it("+15 early in the rest lengthens the total beyond the original", () => {
    const s = adjustRest(startRest(T0, 120, null), T0, 15);
    expect(remainingSeconds(s, T0)).toBe(135);
    expect(remainingFraction(s, T0)).toBe(1);
  });

  it("−15 shortens, and stops at zero", () => {
    const s = startRest(T0, 120, null);
    expect(remainingSeconds(adjustRest(s, T0, -15), T0)).toBe(105);
    const tiny = adjustRest(startRest(T0, 10, null), T0, -15);
    expect(remainingSeconds(tiny, T0)).toBe(0);
    expect(isFinished(tiny, T0)).toBe(true);
  });

  it("works on a paused timer and ignores an idle one", () => {
    const paused = togglePause(startRest(T0, 60, null), T0 + 20_000); // 40 s left
    expect(remainingSeconds(adjustRest(paused, T0 + 50_000, 15), T0 + 50_000)).toBe(55);
    expect(adjustRest(IDLE, T0, 15)).toBe(IDLE);
  });
});

describe("togglePause (Space)", () => {
  it("freezes the remaining time and resumes from it", () => {
    const running = startRest(T0, 120, 3);
    const paused = togglePause(running, T0 + 50_000); // 70 s left
    expect(paused.status).toBe("paused");
    expect(remainingSeconds(paused, T0 + 500_000)).toBe(70); // time passes, nothing changes
    const resumed = togglePause(paused, T0 + 500_000);
    expect(resumed.status).toBe("running");
    expect(remainingSeconds(resumed, T0 + 510_000)).toBe(60);
    expect(resumed.status === "running" && resumed.nextSet).toBe(3);
  });

  it("a finished or idle timer is not paused", () => {
    const done = startRest(T0, 5, null);
    expect(togglePause(done, T0 + 6_000)).toBe(done);
    expect(togglePause(IDLE, T0)).toBe(IDLE);
  });
});

describe("skipRest", () => {
  it("goes idle", () => {
    expect(skipRest()).toEqual(IDLE);
  });
});

describe("restSecondsFor", () => {
  it("the exercise's own rest, else the user's default, else 90 s", () => {
    expect(restSecondsFor(120, 60)).toBe(120);
    expect(restSecondsFor(null, 75)).toBe(75);
    expect(restSecondsFor(undefined, undefined)).toBe(90);
  });

  it("is clamped to 5 s … 15 min", () => {
    expect(restSecondsFor(0, 90)).toBe(5);
    expect(restSecondsFor(5000, 90)).toBe(900);
  });
});
