import { describe, expect, it } from "vitest";
import { attentionItems, calorieCompliance, lastActivity, pickForStrip, sortByAttention, sortForList, weekSummary, weightChange } from "./clientSignals";
import type { TrainerCalendarSessionResponse, TrainerClientResponse } from "./types";

const NOW = new Date("2026-09-29T12:00:00Z");

function client(over: Partial<TrainerClientResponse> & { clientId: number }): TrainerClientResponse {
  return {
    clientEmail: `c${over.clientId}@x.hu`,
    clientFirstName: `Kliens${over.clientId}`,
    clientLastName: null,
    activeSince: "2026-08-17",
    weightTrend: [],
    assignedPlanCount: 0,
    workoutsPerWeek: 0,
    lastActivityAt: "2026-09-29T08:00:00Z",
    lastWeightAt: "2026-09-28",
    missedWorkoutCount: 0,
    avgCalories7d: null,
    prCount7d: 0,
    ...over,
  };
}

describe("attentionItems", () => {
  const inactive = client({ clientId: 1, lastActivityAt: "2026-09-23T08:00:00Z" });
  const missed = client({ clientId: 2, missedWorkoutCount: 2 });
  const record = client({ clientId: 3, prCount7d: 3 });
  const quiet = client({ clientId: 4 });

  it("orders inactive, unread, missed, record and leaves quiet clients out", () => {
    const items = attentionItems([quiet, record, missed, inactive], [{ clientId: 4, unreadCount: 2, lastMessage: "Szia" }], NOW);
    expect(items.map((i) => [i.kind, i.clientId])).toEqual([
      ["inactive", 1],
      ["unread", 4],
      ["missed", 2],
      ["record", 3],
    ]);
  });
  it("carries the day count, the unread preview and the record count", () => {
    const items = attentionItems([inactive, record], [{ clientId: 3, unreadCount: 1, lastMessage: "Kész!" }], NOW);
    expect(items.find((i) => i.kind === "inactive")?.count).toBe(6);
    expect(items.find((i) => i.kind === "unread")?.preview).toBe("Kész!");
    expect(items.find((i) => i.kind === "record")?.count).toBe(3);
  });
  it("is empty when nothing needs the trainer", () => {
    expect(attentionItems([quiet], [{ clientId: 4, unreadCount: 0, lastMessage: null }], NOW)).toEqual([]);
  });
});

describe("sortByAttention", () => {
  it("puts inactive → unread → missed first, the rest by name", () => {
    const a = client({ clientId: 1, clientFirstName: "Zita" });
    const b = client({ clientId: 2, clientFirstName: "Anna" });
    const inactive = client({ clientId: 3, clientFirstName: "Péter", lastActivityAt: "2026-09-20T08:00:00Z" });
    const unread = client({ clientId: 4, clientFirstName: "Dóra" });
    const missed = client({ clientId: 5, clientFirstName: "Máté", missedWorkoutCount: 1 });
    const sorted = sortByAttention([a, b, missed, unread, inactive], [{ clientId: 4, unreadCount: 3, lastMessage: null }], NOW);
    expect(sorted.map((c) => c.clientId)).toEqual([3, 4, 5, 2, 1]);
  });
});

describe("weekSummary", () => {
  const s = (over: Partial<TrainerCalendarSessionResponse>): TrainerCalendarSessionResponse => ({
    sessionId: 1,
    clientId: 1,
    clientEmail: "c1@x.hu",
    scheduledFor: "2026-09-28",
    scheduledTime: null,
    templateName: "Láb",
    status: "UPCOMING",
    scheduleId: 1,
    programAssignmentId: null,
    programName: null,
    ...over,
  });
  const sessions = [
    s({ sessionId: 1, scheduledFor: "2026-09-28", status: "DONE" }),
    s({ sessionId: 2, scheduledFor: "2026-09-29", status: "MISSED" }),
    s({ sessionId: 3, scheduledFor: "2026-10-01", status: "UPCOMING", scheduledTime: "18:00:00" }),
    s({ sessionId: 4, scheduledFor: "2026-09-30", status: "CANCELLED" }),
    s({ sessionId: 5, scheduledFor: "2026-10-05", status: "UPCOMING" }),
    s({ sessionId: 6, clientId: 2, scheduledFor: "2026-09-30", status: "DONE" }),
  ];
  it("counts the week, drops cancelled and other clients, keeps date order", () => {
    const w = weekSummary(sessions, 1, "2026-09-28", "2026-09-29");
    expect(w.scheduled).toBe(3);
    expect(w.done).toBe(1);
    expect(w.dots).toEqual(["DONE", "MISSED", "UPCOMING"]);
    expect(w.missedDates).toEqual(["2026-09-29"]);
  });
  it("finds the next upcoming session, even beyond the week", () => {
    expect(weekSummary(sessions, 1, "2026-09-28", "2026-09-29").next?.sessionId).toBe(3);
    expect(weekSummary(sessions, 1, "2026-09-28", "2026-10-02").next?.sessionId).toBe(5);
    expect(weekSummary(sessions, 1, "2026-09-28", "2026-10-09").next).toBeNull();
  });
  it("has nothing for a client with no sessions", () => {
    const w = weekSummary(sessions, 9, "2026-09-28", "2026-09-29");
    expect(w).toMatchObject({ scheduled: 0, done: 0, dots: [], next: null });
  });
});

describe("weightChange", () => {
  const trend = [
    { date: "2026-08-20", weightKg: 75 },
    { date: "2026-09-02", weightKg: 72 },
    { date: "2026-09-27", weightKg: 70.4 },
  ];
  it("is null with no weigh-ins", () => {
    expect(weightChange([], NOW)).toBeNull();
  });
  it("measures the change from the first point inside the window", () => {
    expect(weightChange(trend, NOW)).toEqual({ latestKg: 70.4, deltaKg: -1.6, tone: "neutral" });
  });
  it("colours toward the goal good and away bad", () => {
    expect(weightChange(trend, NOW, 65)?.tone).toBe("good");
    expect(weightChange(trend, NOW, 80)?.tone).toBe("bad");
  });
  it("has a latest weight but no delta with a single point in the window", () => {
    expect(weightChange([{ date: "2026-09-27", weightKg: 70 }], NOW, 65)).toEqual({ latestKg: 70, deltaKg: null, tone: "neutral" });
  });
});

describe("lastActivity", () => {
  it("names never, today, yesterday and N days", () => {
    expect(lastActivity(client({ clientId: 1, lastActivityAt: null }), NOW).kind).toBe("none");
    expect(lastActivity(client({ clientId: 1, lastActivityAt: "2026-09-29T08:00:00Z" }), NOW).kind).toBe("today");
    expect(lastActivity(client({ clientId: 1, lastActivityAt: "2026-09-28T08:00:00Z" }), NOW).kind).toBe("yesterday");
    expect(lastActivity(client({ clientId: 1, lastActivityAt: "2026-09-23T08:00:00Z" }), NOW)).toEqual({ kind: "daysAgo", days: 6 });
  });
});

describe("sortForList", () => {
  const a = client({ clientId: 1, clientFirstName: "Zita", lastActivityAt: "2026-09-29T08:00:00Z" });
  const b = client({ clientId: 2, clientFirstName: "Anna", lastActivityAt: "2026-09-27T08:00:00Z" });
  const never = client({ clientId: 3, clientFirstName: "Béla", lastActivityAt: null });
  it("sorts by name", () => {
    expect(sortForList([a, never, b], "name", [], NOW).map((c) => c.clientId)).toEqual([2, 3, 1]);
  });
  it("sorts by most recent activity with never-active last", () => {
    expect(sortForList([never, b, a], "activity", [], NOW).map((c) => c.clientId)).toEqual([1, 2, 3]);
  });
});

describe("pickForStrip", () => {
  const item = (kind: "inactive" | "unread" | "missed" | "record", clientId: number) => ({ kind, clientId, count: 1 });
  it("takes the first of each kind before a second of the same", () => {
    const items = [item("inactive", 1), item("inactive", 2), item("unread", 3), item("record", 4)];
    expect(pickForStrip(items, 3).map((i) => [i.kind, i.clientId])).toEqual([["inactive", 1], ["unread", 3], ["record", 4]]);
  });
  it("fills the remaining room in order", () => {
    const items = [item("inactive", 1), item("inactive", 2), item("inactive", 3)];
    expect(pickForStrip(items, 3).map((i) => i.clientId)).toEqual([1, 2, 3]);
    expect(pickForStrip(items, 2).map((i) => i.clientId)).toEqual([1, 2]);
  });
});

describe("calorieCompliance", () => {
  it("is the average over the goal, rounded", () => {
    expect(calorieCompliance({ avgCalories7d: 1823, dailyCalorieGoal: 1900 })).toBe(96);
    expect(calorieCompliance({ avgCalories7d: 2100, dailyCalorieGoal: 1900 })).toBe(111);
  });
  it("is null without an average, without a goal, or with a zero goal", () => {
    expect(calorieCompliance({ avgCalories7d: null, dailyCalorieGoal: 1900 })).toBeNull();
    expect(calorieCompliance({ avgCalories7d: 1800, dailyCalorieGoal: null })).toBeNull();
    expect(calorieCompliance({ avgCalories7d: 1800, dailyCalorieGoal: 0 })).toBeNull();
    expect(calorieCompliance({ avgCalories7d: 1800 })).toBeNull();
  });
});
