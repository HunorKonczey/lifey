import { describe, expect, it } from "vitest";
import type { EntitlementResponse } from "./types";

/**
 * Prompt 4's own *Verify* line (docs/landing_page/66-trainer-billing-web-plan.md
 * §7): "a test that the types match a recorded EntitlementResponse fixture."
 * The `satisfies EntitlementResponse` on each fixture below *is* the actual
 * check — it fails `tsc --noEmit` the moment types.ts drifts from what
 * com.lifey.billing.dto.EntitlementResponse (64 §3.2) really sends, field for
 * field. The runtime assertions are defense-in-depth for anyone editing this
 * file without running the type checker.
 */
describe("EntitlementResponse", () => {
  it("a trainer mid-trial fixture satisfies the type", () => {
    const fixture = {
      tier: "PRO",
      source: "TRAINER_TRIAL",
      adsEnabled: false,
      historyDays: null,
      aiCreditsRemaining: null,
      trainer: {
        plan: "PRO",
        status: "TRIALING",
        maxClients: 25,
        activeClients: 2,
        trialEndsAt: "2026-09-11T09:00:00Z",
      },
      expiresAt: "2026-09-11T09:00:00Z",
      checkedAt: "2026-08-28T10:00:00Z",
      graceUntil: "2026-09-04T10:00:00Z",
      degraded: false,
    } satisfies EntitlementResponse;

    expect(Object.keys(fixture).sort()).toEqual(
      [
        "tier", "source", "adsEnabled", "historyDays", "aiCreditsRemaining",
        "trainer", "expiresAt", "checkedAt", "graceUntil", "degraded",
      ].sort(),
    );
    expect(fixture.trainer && Object.keys(fixture.trainer).sort()).toEqual(
      ["plan", "status", "maxClients", "activeClients", "trialEndsAt"].sort(),
    );
  });

  it("a free, non-trainer fixture (null trainer block, real limits) satisfies the type", () => {
    const fixture = {
      tier: "FREE",
      source: "NONE",
      adsEnabled: true,
      historyDays: 30,
      aiCreditsRemaining: 5,
      trainer: null,
      expiresAt: null,
      checkedAt: "2026-08-28T10:00:00Z",
      graceUntil: "2026-09-04T10:00:00Z",
      degraded: false,
    } satisfies EntitlementResponse;

    expect(fixture.tier).toBe("FREE");
    expect(fixture.trainer).toBeNull();
  });

  it("a degraded fail-open fixture (resolver failure, D-M9) still satisfies the type", () => {
    const fixture = {
      tier: "PRO",
      source: "COMP",
      adsEnabled: false,
      historyDays: null,
      aiCreditsRemaining: null,
      trainer: null,
      expiresAt: null,
      checkedAt: "2026-08-28T10:00:00Z",
      graceUntil: "2026-09-04T10:00:00Z",
      degraded: true,
    } satisfies EntitlementResponse;

    expect(fixture.degraded).toBe(true);
  });

  it("a sponsored client fixture (own tier via a trainer's subscription) satisfies the type", () => {
    const fixture = {
      tier: "PRO",
      source: "TRAINER_SPONSORED",
      adsEnabled: false,
      historyDays: null,
      aiCreditsRemaining: null,
      trainer: null,
      expiresAt: "2026-09-28T10:00:00Z",
      checkedAt: "2026-08-28T10:00:00Z",
      graceUntil: "2026-09-04T10:00:00Z",
      degraded: false,
    } satisfies EntitlementResponse;

    expect(fixture.source).toBe("TRAINER_SPONSORED");
  });
});
