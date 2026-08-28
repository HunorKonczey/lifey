import { daysUntil } from "./status";
import type { EntitlementResponse, SubscriptionStatus } from "./types";

/**
 * docs/landing_page/66-trainer-billing-web-plan.md D-T4's escalation table,
 * as a pure function over an `EntitlementResponse` — the same "extract the
 * logic into a plain .ts function" pattern `planPricing.ts`/`status.ts`
 * established in Prompt 5, for the same reason: this project's Vitest config
 * (`environment: "node"`, `.test.ts` only) has no component-rendering
 * infrastructure, so a pure function `AdminBillingBanner.tsx` imports and
 * renders with no further transformation is what makes the table itself
 * testable.
 */
export type BannerTone = "error" | "warning" | "info";

export type BannerKind = "restricted" | "pastDue" | "overLimit" | "trialUrgent" | "trialInfo";

interface BaseBannerState {
  tone: BannerTone;
  /** "yes, for the session" (D-T4) — only ever true for `trialInfo`. */
  dismissible: boolean;
}

// A discriminated union on `kind`, not one flat interface with optional
// fields — so a caller that has already switched on `kind` (the banner
// component's copy lookup) gets `activeClients`/`daysLeft` etc. narrowed to
// non-optional, rather than fighting `| undefined` at every call site.
export type BannerState =
  | (BaseBannerState & { kind: "restricted" | "pastDue" })
  | (BaseBannerState & { kind: "overLimit"; activeClients: number; maxClients: number })
  | (BaseBannerState & { kind: "trialUrgent" | "trialInfo"; daysLeft: number });

// Not in D-T4's table verbatim (which only names CANCELED/EXPIRED), but
// REFUNDED is, like them, absent from the backend's own
// `SeatLimitServiceImpl.CAN_INVITE_STATUSES` (TRIALING/ACTIVE/PAST_DUE only)
// — a REFUNDED trainer is already write-restricted server-side, so folding it
// into the same "workspace is read-only" banner keeps the UI honest about a
// restriction that otherwise has no banner at all.
const RESTRICTED_STATUSES: ReadonlySet<SubscriptionStatus> = new Set(["CANCELED", "EXPIRED", "REFUNDED"]);

const TRIAL_URGENT_MAX_DAYS = 3;
const TRIAL_INFO_MAX_DAYS = 7;

export function bannerStateFor(entitlement: EntitlementResponse | undefined): BannerState | null {
  if (!entitlement) return null;
  // 64's own contract: a downstream failure fails open with `degraded: true`
  // rather than propagating. Telling a trainer their workspace is read-only
  // (or anything else restrictive) off the back of a response we already
  // chose to let through would be actively wrong, not just unhelpful.
  if (entitlement.degraded) return null;
  // 66 §8 edge case 6: a super admin who also holds ROLE_TRAINER resolves to
  // `source: COMP` regardless of their own subscription row — no banner, no
  // limits, ever, for them.
  if (entitlement.source === "COMP") return null;

  const trainer = entitlement.trainer;
  if (!trainer || !trainer.status) return null;

  if (RESTRICTED_STATUSES.has(trainer.status)) {
    return { kind: "restricted", tone: "error", dismissible: false };
  }

  if (trainer.status === "PAST_DUE") {
    return { kind: "pastDue", tone: "warning", dismissible: false };
  }

  if (trainer.maxClients != null && trainer.activeClients > trainer.maxClients) {
    return {
      kind: "overLimit",
      tone: "warning",
      dismissible: false,
      activeClients: trainer.activeClients,
      maxClients: trainer.maxClients,
    };
  }

  if (trainer.status === "TRIALING" && trainer.trialEndsAt) {
    const daysLeft = daysUntil(entitlement.checkedAt, trainer.trialEndsAt);
    if (daysLeft <= TRIAL_URGENT_MAX_DAYS) {
      return { kind: "trialUrgent", tone: "warning", dismissible: false, daysLeft };
    }
    if (daysLeft <= TRIAL_INFO_MAX_DAYS) {
      return { kind: "trialInfo", tone: "info", dismissible: true, daysLeft };
    }
  }

  return null;
}

const TRIAL_INFO_DISMISSED_KEY = "lifey-billing-trial-info-dismissed";

export function isTrialInfoDismissed(): boolean {
  try {
    return sessionStorage.getItem(TRIAL_INFO_DISMISSED_KEY) === "1";
  } catch {
    return false;
  }
}

export function dismissTrialInfo(): void {
  try {
    sessionStorage.setItem(TRIAL_INFO_DISMISSED_KEY, "1");
  } catch {
    /* private browsing / storage disabled */
  }
}
