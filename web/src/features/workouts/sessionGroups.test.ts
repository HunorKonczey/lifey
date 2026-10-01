import { describe, expect, it } from "vitest";
import { groupSessionsByWeek, summarizeSessions, weekStartFor } from "./sessionGroups";
import type { WorkoutSessionResponse } from "./types";

// Thursday 24 Sep 2026; this week is Mon 21 – Sun 27 Sep.
const NOW = new Date(2026, 8, 24, 19);

function session(id: number, start: Date, over: Partial<WorkoutSessionResponse> = {}): WorkoutSessionResponse {
  return {
    id,
    startedAt: start.toISOString(),
    finishedAt: new Date(start.getTime() + 30 * 60_000).toISOString(),
    exercises: [],
    sets: [],
    activeCalories: null,
    averageHeartRate: null,
    healthWorkoutId: null,
    templateId: null,
    templateName: null,
    rpe: null,
    feedbackNote: null,
    trainerComment: null,
    trainerCommentAt: null,
    sessionKind: "STRENGTH",
    activityType: null,
    movingSeconds: null,
    cardio: null,
    splits: [],
    waypoints: [],
    ...over,
  };
}

const ids = (w: { sessions: WorkoutSessionResponse[] }) => w.sessions.map((s) => s.id);

describe("weekStartFor", () => {
  it("is the Monday at local midnight", () => {
    expect(weekStartFor(new Date(2026, 8, 24, 19))).toEqual(new Date(2026, 8, 21));
    expect(weekStartFor(new Date(2026, 8, 21, 0, 5))).toEqual(new Date(2026, 8, 21));
    expect(weekStartFor(new Date(2026, 8, 27, 23, 59))).toEqual(new Date(2026, 8, 21)); // Sunday
  });
});

describe("groupSessionsByWeek", () => {
  it("this week, last week and older weeks, newest first", () => {
    const weeks = groupSessionsByWeek(
      [
        session(1, new Date(2026, 8, 24, 8)),
        session(2, new Date(2026, 8, 22, 7, 45)),
        session(3, new Date(2026, 8, 20, 7, 45)),
        session(4, new Date(2026, 8, 14, 18)),
        session(5, new Date(2026, 8, 8, 18)),
        session(6, new Date(2026, 8, 2, 18)),
      ],
      NOW,
    );
    expect(weeks.map((w) => w.kind)).toEqual(["thisWeek", "lastWeek", "olderWeek", "olderWeek"]);
    expect(ids(weeks[0])).toEqual([1, 2]);
    expect(ids(weeks[1])).toEqual([3, 4]);
    expect(weeks[2].weekStart).toEqual(new Date(2026, 8, 7));
    expect(weeks[2].weekEnd).toEqual(new Date(2026, 8, 13));
    expect(weeks[3].weekStart).toEqual(new Date(2026, 7, 31));
  });

  it("Sunday belongs to the previous week, Monday to this one", () => {
    const weeks = groupSessionsByWeek([session(1, new Date(2026, 8, 21, 6)), session(2, new Date(2026, 8, 20, 22))], NOW);
    expect(weeks.map((w) => w.kind)).toEqual(["thisWeek", "lastWeek"]);
  });

  it("a week spanning a month boundary stays one group with its real range", () => {
    // Mon 28 Sep – Sun 4 Oct 2026
    const now = new Date(2026, 9, 2, 12);
    const weeks = groupSessionsByWeek([session(1, new Date(2026, 9, 1, 9)), session(2, new Date(2026, 8, 29, 9))], now);
    expect(weeks).toHaveLength(1);
    expect(weeks[0].kind).toBe("thisWeek");
    expect(weeks[0].weekStart).toEqual(new Date(2026, 8, 28));
    expect(weeks[0].weekEnd).toEqual(new Date(2026, 9, 4));
  });

  it("across a year boundary", () => {
    const now = new Date(2027, 0, 5, 12);
    const weeks = groupSessionsByWeek([session(1, new Date(2027, 0, 4, 9)), session(2, new Date(2026, 11, 30, 9))], now);
    expect(weeks.map((w) => w.kind)).toEqual(["thisWeek", "lastWeek"]);
    expect(weeks[1].weekStart).toEqual(new Date(2026, 11, 28));
    expect(weeks[1].weekEnd).toEqual(new Date(2027, 0, 3));
  });

  it("an empty list stays empty", () => {
    expect(groupSessionsByWeek([], NOW)).toEqual([]);
  });
});

describe("summarizeSessions", () => {
  it("counts every session, sums finished time, volume and distance", () => {
    const strength = session(1, new Date(2026, 8, 24, 8), {
      sets: [
        { exerciseId: 1, exerciseName: "Bench", reps: 8, weight: 50, performedAt: "" },
        { exerciseId: 1, exerciseName: "Bench", reps: 8, weight: 47.5, performedAt: "" },
      ],
    });
    const run = session(2, new Date(2026, 8, 23, 7), {
      sessionKind: "CARDIO",
      activityType: "RUNNING",
      movingSeconds: 1810,
      cardio: { distanceMeters: 5200 } as WorkoutSessionResponse["cardio"],
    });
    const running = session(3, new Date(2026, 8, 22, 7), { finishedAt: null });
    const s = summarizeSessions([strength, run, running]);
    expect(s.count).toBe(3);
    expect(s.seconds).toBe(30 * 60 + 1810); // the unfinished one adds nothing
    expect(s.volumeKg).toBe(780);
    expect(s.distanceMeters).toBe(5200);
  });

  it("a game does not count its distance; the indoor bike does", () => {
    const game = session(1, new Date(2026, 8, 24), {
      sessionKind: "CARDIO",
      activityType: "FOOTBALL",
      cardio: { distanceMeters: 7000 } as WorkoutSessionResponse["cardio"],
    });
    const bike = session(2, new Date(2026, 8, 24), {
      sessionKind: "CARDIO",
      activityType: "INDOOR_BIKE",
      cardio: { distanceMeters: 12000 } as WorkoutSessionResponse["cardio"],
    });
    expect(summarizeSessions([game, bike]).distanceMeters).toBe(12000);
  });
});
