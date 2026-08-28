import { describe, expect, it } from "vitest";
import { trainerBillingStateFor } from "./billingGate";
import type { EntitlementResponse, SubscriptionStatus, TrainerEntitlement } from "./types";

function entitlement(trainer: TrainerEntitlement | null, overrides: Partial<EntitlementResponse> = {}): EntitlementResponse {
  return {
    tier: "PRO",
    source: "STRIPE",
    adsEnabled: false,
    historyDays: null,
    aiCreditsRemaining: null,
    trainer,
    expiresAt: null,
    checkedAt: "2026-08-28T09:00:00Z",
    graceUntil: null,
    degraded: false,
    ...overrides,
  };
}

function trainer(overrides: Partial<TrainerEntitlement>): TrainerEntitlement {
  return { plan: "STARTER", status: "ACTIVE", maxClients: 5, activeClients: 2, trialEndsAt: null, ...overrides };
}

describe("trainerBillingStateFor — the client-side mirror of SeatLimitServiceImpl.state()", () => {
  it.each<SubscriptionStatus>(["CANCELED", "EXPIRED", "REFUNDED"])("%s is RESTRICTED", (status) => {
    expect(trainerBillingStateFor(entitlement(trainer({ status })))).toBe("RESTRICTED");
  });

  it.each<SubscriptionStatus>(["TRIALING", "ACTIVE", "PAST_DUE"])("%s within the seat limit is OK", (status) => {
    expect(trainerBillingStateFor(entitlement(trainer({ status, activeClients: 3, maxClients: 5 })))).toBe("OK");
  });

  it("no trainer block (non-trainer caller) is RESTRICTED", () => {
    expect(trainerBillingStateFor(entitlement(null))).toBe("RESTRICTED");
  });

  it("no subscription yet (status null) is RESTRICTED", () => {
    expect(trainerBillingStateFor(entitlement(trainer({ status: null, plan: null, maxClients: null })))).toBe("RESTRICTED");
  });

  it("activeClients > maxClients is OVER_LIMIT", () => {
    expect(trainerBillingStateFor(entitlement(trainer({ activeClients: 6, maxClients: 5 })))).toBe("OVER_LIMIT");
  });

  it("activeClients === maxClients (exactly at the limit) is still OK — matches state()'s strict '>'", () => {
    expect(trainerBillingStateFor(entitlement(trainer({ activeClients: 5, maxClients: 5 })))).toBe("OK");
  });

  it("RESTRICTED outranks OVER_LIMIT — a canceled trainer over their old limit is still RESTRICTED, not OVER_LIMIT", () => {
    expect(
      trainerBillingStateFor(entitlement(trainer({ status: "CANCELED", activeClients: 12, maxClients: 5 }))),
    ).toBe("RESTRICTED");
  });

  it("no entitlement data yet is OK — never block on a guess", () => {
    expect(trainerBillingStateFor(undefined)).toBe("OK");
  });

  it("degraded (64's fail-open contract) is OK, even for an otherwise-restricted status", () => {
    expect(trainerBillingStateFor(entitlement(trainer({ status: "CANCELED" }), { degraded: true }))).toBe("OK");
  });

  it("source COMP (billing disabled, or a super admin who also holds ROLE_TRAINER) is OK, even when over-limit", () => {
    expect(
      trainerBillingStateFor(entitlement(trainer({ activeClients: 99, maxClients: 5 }), { source: "COMP" })),
    ).toBe("OK");
  });
});
