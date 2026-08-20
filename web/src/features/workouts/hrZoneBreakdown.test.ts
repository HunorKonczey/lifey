import { describe, it, expect } from "vitest";
import { buildHrZoneBreakdown } from "./hrZoneBreakdown";
import type { WorkoutSessionResponse, CardioDetailsResponse } from "./types";

/**
 * Parity port of `mobile/test/features/workouts/domain/hr_zone_breakdown_test.dart`
 * (docs/cardio/60 §8 C9w.1 kész-ha) — same input/output pairs, same case
 * names, ported to the web's session shape.
 */

function cardio(zones: (number | null)[] = [null, null, null, null, null]): CardioDetailsResponse {
  return {
    distanceMeters: null, elevationGainMeters: null, elevationLossMeters: null, maxAltitudeMeters: null,
    steps: null, avgCadence: null, maxCadence: null,
    best1kSeconds: null, best5kSeconds: null, best10kSeconds: null,
    avgWatts: null, maxWatts: null, resistanceLevel: null, deviceCalories: null, maxHeartRate: null,
    hrZone1Seconds: zones[0], hrZone2Seconds: zones[1], hrZone3Seconds: zones[2],
    hrZone4Seconds: zones[3], hrZone5Seconds: zones[4],
    intensity: null, venue: null, gameFormat: null, scorePoints: null, scoreAssists: null, scoreRebounds: null,
    distanceSource: null, caloriesSource: null, routePolyline: null, routePointCount: null,
    backpackWeightKg: null, avgGapSecondsPerKm: null,
    weatherTempC: null, weatherWindKph: null, weatherPrecipMm: null, weatherCondition: null,
  };
}

function session({
  zones = [null, null, null, null, null] as (number | null)[],
  grossSeconds = 3600,
  activityType = "BASKETBALL" as WorkoutSessionResponse["activityType"],
  hasCardio = true,
  hasFinishedAt = true,
}: {
  zones?: (number | null)[];
  grossSeconds?: number;
  activityType?: WorkoutSessionResponse["activityType"];
  hasCardio?: boolean;
  hasFinishedAt?: boolean;
} = {}): WorkoutSessionResponse {
  const startedAt = "2026-08-17T19:00:00Z";
  const finishedAt = hasFinishedAt
    ? new Date(new Date(startedAt).getTime() + grossSeconds * 1000).toISOString()
    : null;
  return {
    id: 1, startedAt, finishedAt,
    exercises: [], sets: [],
    activeCalories: null, averageHeartRate: null, healthWorkoutId: null,
    templateId: null, templateName: null, rpe: null, feedbackNote: null,
    trainerComment: null, trainerCommentAt: null,
    sessionKind: hasCardio ? "CARDIO" : "STRENGTH",
    activityType: hasCardio ? activityType : null,
    movingSeconds: hasCardio ? grossSeconds : null,
    cardio: hasCardio ? cardio(zones) : null,
    splits: [], waypoints: [],
  };
}

describe("no data at all", () => {
  it("a session with no zone columns has no breakdown", () => {
    expect(buildHrZoneBreakdown(session())).toBeNull();
  });

  it("all-zero zone columns count as no data, not as a flat session", () => {
    expect(buildHrZoneBreakdown(session({ zones: [0, 0, 0, 0, 0] }))).toBeNull();
  });

  it("a session with no cardio block at all has no breakdown", () => {
    expect(buildHrZoneBreakdown(session({ hasCardio: false }))).toBeNull();
  });
});

describe("shares", () => {
  it("always lists five zones, including untouched ones", () => {
    const breakdown = buildHrZoneBreakdown(session({ zones: [null, 1800, 1800, null, null] }))!;
    expect(breakdown.slices).toHaveLength(5);
    expect(breakdown.slices[0].seconds).toBe(0);
    expect(breakdown.slices[1].seconds).toBe(1800);
    expect(breakdown.slices[3].seconds).toBe(0);
  });

  it("fractions sum to one and none exceeds it", () => {
    const breakdown = buildHrZoneBreakdown(session({ zones: [600, 1200, 900, 600, 300] }))!;
    const sum = breakdown.slices.reduce((a, s) => a + s.fraction, 0);
    expect(sum).toBeCloseTo(1.0, 9);
    for (const slice of breakdown.slices) expect(slice.fraction).toBeLessThanOrEqual(1.0);
  });
});

describe("the sum can never exceed the gross time (§9)", () => {
  it("an over-long zone sum is capped and flagged", () => {
    // The double-write case: 90 minutes of zones on a 60 minute session.
    const breakdown = buildHrZoneBreakdown(
      session({ zones: [1200, 1200, 1200, 1200, 600], grossSeconds: 3600 }),
    )!;
    expect(breakdown.exceedsGross).toBe(true);
    expect(breakdown.totalSeconds).toBe(3600);
    expect(breakdown.coverageFraction).toBe(1.0);
  });

  it("a consistent full-coverage session is not flagged", () => {
    const breakdown = buildHrZoneBreakdown(
      session({ zones: [600, 1200, 900, 600, 300], grossSeconds: 3600 }),
    )!;
    expect(breakdown.exceedsGross).toBe(false);
    expect(breakdown.coverageFraction).toBe(1.0);
    expect(breakdown.isPartial).toBe(false);
  });
});

describe("partial coverage", () => {
  it("zones covering part of the session report that share", () => {
    // A watch paired half-way through: 37 of 60 minutes measured.
    const breakdown = buildHrZoneBreakdown(
      session({ zones: [600, 900, 720, null, null], grossSeconds: 3600 }),
    )!;
    expect(breakdown.isPartial).toBe(true);
    expect(breakdown.coverageFraction).toBeCloseTo(2220 / 3600, 9);
  });

  it("a couple of rounding seconds short is not called partial", () => {
    const breakdown = buildHrZoneBreakdown(
      session({ zones: [1800, 1798, null, null, null], grossSeconds: 3600 }),
    )!;
    expect(breakdown.isPartial).toBe(false);
  });

  it("an unknown gross time is treated as fully covered, not as partial", () => {
    const breakdown = buildHrZoneBreakdown(session({ zones: [null, 900, null, null, null], hasFinishedAt: false }))!;
    expect(breakdown.coverageFraction).toBe(1.0);
    expect(breakdown.isPartial).toBe(false);
  });
});

describe("the spoken verdict (M43 — colour alone is not accessible)", () => {
  it("a third or more at threshold and above is a hard session", () => {
    const breakdown = buildHrZoneBreakdown(session({ zones: [300, 600, 900, 1200, 600] }))!;
    expect(breakdown.hardFraction).toBeGreaterThanOrEqual(0.33);
    expect(breakdown.intensity).toBe("hard");
  });

  it("almost nothing above tempo is an easy session", () => {
    const breakdown = buildHrZoneBreakdown(session({ zones: [1800, 1500, 240, 60, null] }))!;
    expect(breakdown.intensity).toBe("easy");
  });

  it("the band between the two is balanced", () => {
    const breakdown = buildHrZoneBreakdown(session({ zones: [600, 1200, 1200, 500, 100] }))!;
    expect(breakdown.intensity).toBe("balanced");
  });

  it("the verdict reads the measured time, not the session length", () => {
    // 10 minutes measured, all of it at maximum, on an hour-long match: a
    // hard *measurement*, reported as such next to the "17% of the session"
    // note rather than diluted to "easy".
    const breakdown = buildHrZoneBreakdown(
      session({ zones: [null, null, null, null, 600], grossSeconds: 3600 }),
    )!;
    expect(breakdown.intensity).toBe("hard");
    expect(breakdown.isPartial).toBe(true);
  });
});
