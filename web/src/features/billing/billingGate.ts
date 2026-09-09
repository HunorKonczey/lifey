import type { EntitlementResponse, SubscriptionStatus } from "./types";

/**
 * docs/landing_page/66-trainer-billing-web-plan.md D-T5 — the client-side
 * mirror of `com.lifey.billing.TrainerBillingState`
 * (`backend/src/main/java/com/lifey/billing/service/SeatLimitServiceImpl.java`,
 * `state()`), so the four gated actions (send invite, assign content, assign
 * a program, schedule a workout) agree with what the backend will actually
 * accept before the trainer spends time filling out a drawer for nothing.
 * Deliberately the *same* rule for all four, even though the backend's own
 * `assertCanSendInvite` is a little stricter (it also counts pending invites)
 * — matching `state()` exactly, rather than each call site inventing its own
 * threshold, is what keeps `BillingBlockedDialog`'s copy from drifting across
 * the four sites (D-T5's own stated reason for the shared component). The
 * backend's stricter invite check remains the real enforcement; this is only
 * the "don't bother opening the drawer" pre-check.
 */
export type TrainerBillingState = "OK" | "OVER_LIMIT" | "RESTRICTED";

const ENTITLING_STATUSES: ReadonlySet<SubscriptionStatus> = new Set(["TRIALING", "ACTIVE", "PAST_DUE"]);

export function trainerBillingStateFor(entitlement: EntitlementResponse | undefined): TrainerBillingState {
  if (!entitlement) return "OK"; // not loaded yet — never block on a guess
  // `source: "COMP"` covers both the super-admin case (66 §8 edge case 6) and
  // `lifey.billing.enabled=false`'s open-for-everyone rollback response
  // (see bannerState.ts's identical check, and its landed notes on why the
  // backend deliberately overloads this one value for both). Either way,
  // `SeatLimitServiceImpl` itself returns OK unconditionally here, so this
  // mirrors the real enforcement, not just the banner's display choice.
  if (entitlement.degraded || entitlement.source === "COMP") return "OK";

  const trainer = entitlement.trainer;
  if (!trainer || !trainer.status || !ENTITLING_STATUSES.has(trainer.status)) return "RESTRICTED";
  if (trainer.maxClients != null && trainer.activeClients > trainer.maxClients) return "OVER_LIMIT";
  return "OK";
}
