import { describe, expect, it } from "vitest";
import { buildWeightHero, monthThird } from "./weightHero";
import type { WeightResponse } from "./types";

const w = (id: number, date: string, weight: number): WeightResponse => ({ id, date, weight });
const NOW = new Date(2026, 8, 27, 12);

/** 28 days of a steady 0.1 kg/day loss from 72.0 → 69.3, one entry a day. */
function steadyLoss(): WeightResponse[] {
  return Array.from({ length: 28 }, (_, i) => {
    const d = new Date(2026, 8, 27 - (27 - i));
    const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    return w(i + 1, iso, Math.round((72 - i * 0.1) * 10) / 10);
  });
}

describe("buildWeightHero", () => {
  it("a fresh account has no hero", () => {
    expect(buildWeightHero([], 65, NOW)).toBeNull();
  });

  it("the first entry: the weight, no deltas, no average, no projection", () => {
    const hero = buildWeightHero([w(1, "2026-09-27", 69.6)], 65, NOW)!;
    expect(hero.latest.weight).toBe(69.6);
    expect(hero.weekDelta).toBeNull();
    expect(hero.sinceStart).toBeNull();
    expect(hero.average7).toBeNull();
    expect(hero.pace).toBeNull();
    expect(hero.projection).toBeNull();
    // the goal still gives "still 4.6 kg"
    expect(hero.remainingKg).toBeCloseTo(4.6, 5);
  });

  it("no goal: no remaining, no band position, no projection", () => {
    const hero = buildWeightHero(steadyLoss(), null, NOW)!;
    expect(hero.goalKg).toBeNull();
    expect(hero.remainingKg).toBeNull();
    expect(hero.progress).toBeNull();
    expect(hero.projection).toBeNull();
    expect(hero.reached).toBe(false);
  });

  it("a steady loss: week delta, since start, the band position and an on-track projection", () => {
    const hero = buildWeightHero(steadyLoss(), 65, NOW)!;
    expect(hero.latest.weight).toBe(69.3);
    expect(hero.weekDelta).toBeCloseTo(-0.7, 5); // 69.3 − 70.0 a week before
    expect(hero.sinceStart).toBeCloseTo(-2.7, 5);
    expect(hero.start.weight).toBe(72);
    expect(hero.remainingKg).toBeCloseTo(4.3, 5);
    expect(hero.progress).toBeCloseTo(2.7 / 7, 3);
    expect(hero.projection?.state).toBe("onTrack");
    expect(hero.pace).toBeLessThan(0);
    expect(hero.average7).not.toBeNull();
  });

  it("the week delta needs an entry a week old — two entries a day apart have none", () => {
    const hero = buildWeightHero([w(1, "2026-09-26", 70), w(2, "2026-09-27", 69.8)], 65, NOW)!;
    expect(hero.weekDelta).toBeNull();
    expect(hero.sinceStart).toBeCloseTo(-0.2, 5);
  });

  it("the goal reached is flagged, with the band full", () => {
    const hero = buildWeightHero([w(1, "2026-08-01", 72), w(2, "2026-09-27", 65.1)], 65, NOW)!;
    expect(hero.reached).toBe(true);
    expect(hero.progress).toBeCloseTo(6.9 / 7, 3);
  });

  it("a goal above the start (gaining) measures the band the other way", () => {
    const hero = buildWeightHero([w(1, "2026-08-01", 60), w(2, "2026-09-27", 63)], 66, NOW)!;
    expect(hero.progress).toBeCloseTo(0.5, 5);
    expect(hero.remainingKg).toBeCloseTo(3, 5);
  });

  it("moving away from the goal clamps the band at 0", () => {
    const hero = buildWeightHero([w(1, "2026-08-01", 70), w(2, "2026-09-27", 72)], 65, NOW)!;
    expect(hero.progress).toBe(0);
  });

  it("start equals goal: no band", () => {
    expect(buildWeightHero([w(1, "2026-08-01", 65), w(2, "2026-09-27", 66)], 65, NOW)!.progress).toBeNull();
  });
});

describe("monthThird", () => {
  it("early, mid and late thirds of a month", () => {
    expect(monthThird(new Date(2026, 11, 3))).toBe("early");
    expect(monthThird(new Date(2026, 11, 10))).toBe("early");
    expect(monthThird(new Date(2026, 11, 11))).toBe("mid");
    expect(monthThird(new Date(2026, 11, 20))).toBe("mid");
    expect(monthThird(new Date(2026, 11, 21))).toBe("late");
  });
});
