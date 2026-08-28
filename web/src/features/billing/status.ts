import type { SubscriptionStatus } from "./types";

/**
 * Days remaining between two server-provided timestamps — never `Date.now()`
 * (docs/landing_page/66-trainer-billing-web-plan.md §9 risk 5: a trial length
 * computed from the device's own clock produces off-by-a-day banners, and
 * worse, a falsely-"expired" one for a trainer whose clock is ahead).
 * `checkedAt` is `EntitlementResponse.checkedAt` — the server's own clock
 * reading at resolve time — paired with `trainer.trialEndsAt`, both from the
 * same response. Rounds up, so "23 hours left" reads as "1 day left", not 0.
 */
export function daysUntil(checkedAtIso: string, targetIso: string): number {
  const ms = new Date(targetIso).getTime() - new Date(checkedAtIso).getTime();
  return Math.max(0, Math.ceil(ms / (24 * 60 * 60 * 1000)));
}

/** The four states 66 §3 names, plus the two extra `SubscriptionStatus` values a trainer's own row can actually hold. */
export type StatusPillTone = "trial" | "active" | "warning" | "error" | "muted";

export interface StatusPill {
  /** Key into the `admin.billing` message namespace. */
  labelKey: "statusTrial" | "statusActive" | "statusPastDue" | "statusCanceled" | "statusExpired" | "statusRefunded";
  tone: StatusPillTone;
}

/** com.lifey.billing.entity.SubscriptionStatus -> the plan card's status pill (66 §3 point 1). */
export function statusPillFor(status: SubscriptionStatus): StatusPill {
  switch (status) {
    case "TRIALING":
      return { labelKey: "statusTrial", tone: "trial" };
    case "ACTIVE":
      return { labelKey: "statusActive", tone: "active" };
    case "PAST_DUE":
      return { labelKey: "statusPastDue", tone: "warning" };
    case "CANCELED":
      return { labelKey: "statusCanceled", tone: "error" };
    case "EXPIRED":
      return { labelKey: "statusExpired", tone: "error" };
    case "REFUNDED":
      return { labelKey: "statusRefunded", tone: "muted" };
  }
}
