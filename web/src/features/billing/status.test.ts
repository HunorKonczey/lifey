import { describe, expect, it } from "vitest";
import { daysUntil, statusPillFor } from "./status";

describe("daysUntil", () => {
  it("rounds up so a partial day still reads as at least 1", () => {
    expect(daysUntil("2026-08-28T09:00:00Z", "2026-08-29T08:59:00Z")).toBe(1);
  });

  it("computes whole days between two server timestamps", () => {
    expect(daysUntil("2026-08-28T09:00:00Z", "2026-09-03T09:00:00Z")).toBe(6);
  });

  it("never goes negative for a target already in the past", () => {
    expect(daysUntil("2026-08-28T09:00:00Z", "2026-08-20T09:00:00Z")).toBe(0);
  });
});

describe("statusPillFor", () => {
  it("maps every SubscriptionStatus to a distinct label key", () => {
    const statuses = ["TRIALING", "ACTIVE", "PAST_DUE", "CANCELED", "EXPIRED", "REFUNDED"] as const;
    const pills = statuses.map(statusPillFor);
    expect(new Set(pills.map((p) => p.labelKey)).size).toBe(statuses.length);
  });

  it("PAST_DUE and CANCELED read as warning/error, matching 63 §7.5's dunning-window UX", () => {
    expect(statusPillFor("PAST_DUE").tone).toBe("warning");
    expect(statusPillFor("CANCELED").tone).toBe("error");
  });
});
