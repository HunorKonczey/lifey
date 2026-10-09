import { describe, expect, it } from "vitest";
import { inviteStatus, inviteUrgent, canResend, historyRows, outcomeAt, canRemind, joinUrl, nextReminderAt } from "./invites";
import type { TrainerInviteHistoryResponse } from "./types";

const now = Date.parse("2026-10-01T12:00:00Z");

describe("invite status", () => {
  it("is pending until expiresAt, expired from then on", () => {
    expect(inviteStatus("2026-10-02T12:00:00Z", now)).toBe("PENDING");
    expect(inviteStatus("2026-10-01T12:00:00Z", now)).toBe("EXPIRED");
    expect(inviteStatus("2026-10-01T11:00:00Z", now)).toBe("EXPIRED");
  });
  it("is urgent only in the last three hours of a live invite", () => {
    expect(inviteUrgent("2026-10-01T14:00:00Z", now)).toBe(true);
    expect(inviteUrgent("2026-10-01T16:00:00Z", now)).toBe(false);
    expect(inviteUrgent("2026-10-01T11:00:00Z", now)).toBe(false);
  });
});

describe("invite history helpers", () => {
  const row = (over: Partial<TrainerInviteHistoryResponse>): TrainerInviteHistoryResponse => ({
    id: 1,
    clientEmail: "a@x.hu",
    outcome: "ACCEPTED",
    createdAt: "2026-10-01T10:00:00Z",
    expiresAt: "2026-10-02T10:00:00Z",
    respondedAt: "2026-10-01T11:00:00Z",
    endedAt: null,
    ...over,
  });

  it("historyRows drops pending rows: they live in the list above, with their actions", () => {
    const rows = [row({ id: 1, outcome: "PENDING" }), row({ id: 2, outcome: "EXPIRED" }), row({ id: 3 })];
    expect(historyRows(rows).map((r) => r.id)).toEqual([2, 3]);
  });

  it("only a lapsed or withdrawn invite can be re-sent", () => {
    expect(canResend("EXPIRED")).toBe(true);
    expect(canResend("CANCELLED")).toBe(true);
    expect(canResend("ACCEPTED")).toBe(false);
    expect(canResend("DECLINED")).toBe(false);
    expect(canResend("PENDING")).toBe(false);
  });

  it("outcomeAt is the moment that decided the outcome", () => {
    expect(outcomeAt(row({ outcome: "ACCEPTED" }))).toBe("2026-10-01T11:00:00Z");
    expect(outcomeAt(row({ outcome: "DECLINED", respondedAt: "2026-10-01T12:00:00Z" }))).toBe("2026-10-01T12:00:00Z");
    expect(outcomeAt(row({ outcome: "CANCELLED", respondedAt: null, endedAt: "2026-10-01T10:30:00Z" }))).toBe("2026-10-01T10:30:00Z");
    expect(outcomeAt(row({ outcome: "EXPIRED", respondedAt: null }))).toBe("2026-10-02T10:00:00Z");
  });

  it("falls back to the send time rather than crash when a stamp is missing", () => {
    expect(outcomeAt(row({ outcome: "ACCEPTED", respondedAt: null }))).toBe("2026-10-01T10:00:00Z");
    expect(outcomeAt(row({ outcome: "CANCELLED", respondedAt: null, endedAt: null }))).toBe("2026-10-01T10:00:00Z");
  });
});

describe("reminders (LIF-103)", () => {
  const hour = 60 * 60 * 1000;
  const created = new Date("2026-06-01T08:00:00Z").getTime();
  const invite = (extra: { lastRemindedAt?: string | null } = {}) => ({
    createdAt: new Date(created).toISOString(),
    expiresAt: new Date(created + 24 * hour).toISOString(),
    ...extra,
  });

  it("cannot be sent in the first hours after the invite", () => {
    expect(canRemind(invite(), created + hour)).toBe(false);
    expect(canRemind(invite(), created + 4 * hour - 1)).toBe(false);
  });

  it("can be sent once the cooldown has passed, and counts it from the last reminder", () => {
    expect(canRemind(invite(), created + 4 * hour)).toBe(true);
    const reminded = invite({ lastRemindedAt: new Date(created + 5 * hour).toISOString() });
    expect(nextReminderAt(reminded)).toBe(created + 9 * hour);
    expect(canRemind(reminded, created + 6 * hour)).toBe(false);
    expect(canRemind(reminded, created + 9 * hour)).toBe(true);
  });

  it("is not offered for an invite that has run out", () => {
    expect(canRemind(invite(), created + 25 * hour)).toBe(false);
  });
});

describe("joinUrl", () => {
  it("is this site's own join page for the token", () => {
    expect(joinUrl("https://app.lifey.test", "abc-DEF_123")).toBe("https://app.lifey.test/join/abc-DEF_123");
  });
});
