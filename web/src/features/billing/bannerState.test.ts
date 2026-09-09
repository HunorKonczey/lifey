import { describe, expect, it } from "vitest";
import { bannerStateFor } from "./bannerState";
import type { EntitlementResponse, SubscriptionStatus, TrainerEntitlement } from "./types";

const CHECKED_AT = "2026-08-28T09:00:00Z";

function entitlement(trainer: TrainerEntitlement | null, overrides: Partial<EntitlementResponse> = {}): EntitlementResponse {
  return {
    tier: "PRO",
    source: "STRIPE",
    adsEnabled: false,
    historyDays: null,
    aiCreditsRemaining: null,
    trainer,
    expiresAt: null,
    checkedAt: CHECKED_AT,
    graceUntil: null,
    degraded: false,
    ...overrides,
  };
}

function trainer(overrides: Partial<TrainerEntitlement>): TrainerEntitlement {
  return { plan: "STARTER", status: "ACTIVE", maxClients: 5, activeClients: 2, trialEndsAt: null, ...overrides };
}

function daysFromChecked(days: number): string {
  return new Date(new Date(CHECKED_AT).getTime() + days * 24 * 60 * 60 * 1000).toISOString();
}

describe("bannerStateFor — D-T4's escalation table, one case per row", () => {
  it.each<SubscriptionStatus>(["CANCELED", "EXPIRED", "REFUNDED"])(
    "%s renders the non-dismissible 'restricted' (error) banner",
    (status) => {
      const state = bannerStateFor(entitlement(trainer({ status })));
      expect(state).toEqual({ kind: "restricted", tone: "error", dismissible: false });
    },
  );

  it("PAST_DUE renders the non-dismissible 'pastDue' (warning) banner", () => {
    const state = bannerStateFor(entitlement(trainer({ status: "PAST_DUE" })));
    expect(state).toEqual({ kind: "pastDue", tone: "warning", dismissible: false });
  });

  it("PAST_DUE outranks over-limit — a lapsed card is the more urgent problem", () => {
    const state = bannerStateFor(entitlement(trainer({ status: "PAST_DUE", activeClients: 12, maxClients: 5 })));
    expect(state?.kind).toBe("pastDue");
  });

  it("ACTIVE with activeClients > maxClients renders the non-dismissible 'overLimit' (warning) banner with the counts", () => {
    const state = bannerStateFor(entitlement(trainer({ status: "ACTIVE", activeClients: 12, maxClients: 5 })));
    expect(state).toEqual({
      kind: "overLimit",
      tone: "warning",
      dismissible: false,
      activeClients: 12,
      maxClients: 5,
    });
  });

  it("ACTIVE at or under the limit renders no banner", () => {
    expect(bannerStateFor(entitlement(trainer({ status: "ACTIVE", activeClients: 5, maxClients: 5 })))).toBeNull();
  });

  it("TRIALING with <= 3 days left renders the non-dismissible 'trialUrgent' (warning) banner", () => {
    const state = bannerStateFor(
      entitlement(trainer({ status: "TRIALING", trialEndsAt: daysFromChecked(3) })),
    );
    expect(state).toEqual({ kind: "trialUrgent", tone: "warning", dismissible: false, daysLeft: 3 });
  });

  it("TRIALING with 4-7 days left renders the dismissible 'trialInfo' (info) banner", () => {
    const state = bannerStateFor(
      entitlement(trainer({ status: "TRIALING", trialEndsAt: daysFromChecked(7) })),
    );
    expect(state).toEqual({ kind: "trialInfo", tone: "info", dismissible: true, daysLeft: 7 });
  });

  it("TRIALING with > 7 days left renders no banner — silence in the first week is deliberate", () => {
    expect(
      bannerStateFor(entitlement(trainer({ status: "TRIALING", trialEndsAt: daysFromChecked(8) }))),
    ).toBeNull();
  });

  it("a TRIALING trainer who is also over-limit still gets 'overLimit', not a trial banner", () => {
    const state = bannerStateFor(
      entitlement(trainer({ status: "TRIALING", trialEndsAt: daysFromChecked(2), activeClients: 12, maxClients: 5 })),
    );
    expect(state?.kind).toBe("overLimit");
  });

  it("no trainer block (non-trainer caller) renders no banner", () => {
    expect(bannerStateFor(entitlement(null))).toBeNull();
  });

  it("a trainer with no subscription yet (status null) renders no banner", () => {
    expect(bannerStateFor(entitlement(trainer({ status: null, plan: null })))).toBeNull();
  });

  it("degraded (64's fail-open contract) suppresses every banner, even an otherwise-restricted status", () => {
    expect(
      bannerStateFor(entitlement(trainer({ status: "CANCELED" }), { degraded: true })),
    ).toBeNull();
  });

  it("source COMP (66 §8 edge case 6: a super admin who also holds ROLE_TRAINER) suppresses every banner", () => {
    expect(
      bannerStateFor(entitlement(trainer({ status: "CANCELED", activeClients: 99, maxClients: 5 }), { source: "COMP" })),
    ).toBeNull();
  });
});
