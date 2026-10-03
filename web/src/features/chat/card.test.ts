import { describe, expect, it } from "vitest";
import {
  cardPreviewKey,
  distanceKm,
  durationMinutes,
  isCardio,
  isKnownCard,
  prDelta,
  prUnit,
  recordCount,
} from "./card";
import type { MessageCardResponse } from "./types";

const base = { sessionId: 481, occurredAt: "2026-10-03T07:12:00Z" };

const workout = (over: Partial<NonNullable<MessageCardResponse["workout"]>> = {}): MessageCardResponse => ({
  ...base,
  kind: "WORKOUT",
  pr: null,
  workout: {
    workoutKind: "STRENGTH",
    title: "Push day",
    durationSeconds: 3600,
    volumeKg: 8450,
    exerciseCount: 6,
    distanceMeters: null,
    recordCount: 2,
    ...over,
  },
});

const pr = (over: Partial<NonNullable<MessageCardResponse["pr"]>> = {}): MessageCardResponse => ({
  ...base,
  kind: "PR",
  workout: null,
  pr: {
    exerciseName: "Bench press",
    prType: "MAX_WEIGHT",
    value: 102.5,
    previousValue: 100,
    weightKg: 102.5,
    reps: 3,
    ...over,
  },
});

describe("which cards this build can draw", () => {
  it("knows a workout and a record that carry their body", () => {
    expect(isKnownCard(workout())).toBe(true);
    expect(isKnownCard(pr())).toBe(true);
  });

  it("does not know a kind from a newer app, or a known kind with no body", () => {
    expect(isKnownCard({ ...base, kind: "MEAL", workout: null, pr: null })).toBe(false);
    expect(isKnownCard({ ...base, kind: "PR", workout: null, pr: null })).toBe(false);
    expect(isKnownCard({ ...base, kind: "WORKOUT", workout: null, pr: null })).toBe(false);
  });
});

describe("the preview in the conversation list", () => {
  it("names the kind, so a card never reads as a deleted message", () => {
    expect(cardPreviewKey(workout())).toBe("cardPreviewWorkout");
    expect(cardPreviewKey(pr())).toBe("cardPreviewRecord");
  });
});

describe("workout numbers", () => {
  it("tells cardio from strength", () => {
    expect(isCardio(workout({ workoutKind: "CARDIO" }))).toBe(true);
    expect(isCardio(workout())).toBe(false);
    expect(isCardio(pr())).toBe(false);
  });

  it("rounds a duration to whole minutes, at least one, and draws nothing for none", () => {
    expect(durationMinutes(3510)).toBe(59);
    expect(durationMinutes(20)).toBe(1);
    expect(durationMinutes(0)).toBeNull();
    expect(durationMinutes(null)).toBeNull();
  });

  it("converts metres to kilometres and draws nothing for none", () => {
    expect(distanceKm(5200)).toBe(5.2);
    expect(distanceKm(0)).toBeNull();
    expect(distanceKm(undefined)).toBeNull();
  });

  it("counts records only on a workout, and zero or unknown is nothing", () => {
    expect(recordCount(workout())).toBe(2);
    expect(recordCount(workout({ recordCount: null }))).toBe(0);
    expect(recordCount(pr())).toBe(0);
  });
});

describe("record numbers", () => {
  it("counts a reps record in reps and the others in kilograms", () => {
    expect(prUnit({ prType: "REPS_AT_WEIGHT" })).toBe("reps");
    expect(prUnit({ prType: "MAX_WEIGHT" })).toBe("kg");
    expect(prUnit({ prType: "ESTIMATED_ONE_RM" })).toBe("kg");
  });

  it("says how far it moved the old record, rounded to one decimal", () => {
    expect(prDelta({ value: 102.5, previousValue: 100 })).toBe(2.5);
    // 112.8 − 108.7 is 4.099999999999994 in binary floating point.
    expect(prDelta({ value: 112.8, previousValue: 108.7 })).toBe(4.1);
  });

  it("claims nothing for a first record or for no improvement", () => {
    expect(prDelta({ value: 100, previousValue: null })).toBeNull();
    expect(prDelta({ value: 100, previousValue: 100 })).toBeNull();
    expect(prDelta({ value: 90, previousValue: 100 })).toBeNull();
  });
});
