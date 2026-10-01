import { describe, expect, it } from "vitest";
import { inviteStatus, inviteUrgent } from "./invites";

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
