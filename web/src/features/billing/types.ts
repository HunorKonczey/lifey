// Mirrors backend/src/main/java/com/lifey/billing/dto/EntitlementResponse.java and its
// nested types exactly (docs/landing_page/64-billing-backend-plan.md §3.2).

export type EntitlementTier = "FREE" | "PRO";

export type EntitlementSource =
  | "NONE"
  | "STRIPE"
  | "APP_STORE"
  | "PLAY_STORE"
  | "TRAINER_SPONSORED"
  | "TRAINER_TRIAL"
  | "COMP";

/** com.lifey.billing.entity.TrainerPlan — keyed by active client count (63 D-M2). */
export type TrainerPlan = "STARTER" | "PRO" | "STUDIO";

/** com.lifey.billing.entity.SubscriptionStatus (64 §4.4). */
export type SubscriptionStatus = "TRIALING" | "ACTIVE" | "PAST_DUE" | "CANCELED" | "EXPIRED" | "REFUNDED";

/**
 * Present only when the caller holds ROLE_TRAINER — null `plan`/`status` and
 * unlimited-in-effect `maxClients` mean no subscription row yet (trial not
 * started, or billing disabled).
 */
export interface TrainerEntitlement {
  plan: TrainerPlan | null;
  status: SubscriptionStatus | null;
  maxClients: number | null;
  activeClients: number;
  trialEndsAt: string | null;
}

/**
 * The one object a client ever asks for — never a list of feature booleans it
 * has to interpret itself. `historyDays`/`aiCreditsRemaining` are `null` to
 * mean unlimited; `trainer` is `null` for a non-trainer caller.
 */
export interface EntitlementResponse {
  tier: EntitlementTier;
  source: EntitlementSource;
  adsEnabled: boolean;
  historyDays: number | null;
  aiCreditsRemaining: number | null;
  trainer: TrainerEntitlement | null;
  expiresAt: string | null;
  checkedAt: string;
  graceUntil: string | null;
  degraded: boolean;
}

/** com.lifey.billing.dto.BillingInterval — monthly vs. the 2-months-free yearly plan. */
export type BillingInterval = "MONTHLY" | "YEARLY";

export interface CheckoutSessionRequest {
  plan: TrainerPlan;
  interval: BillingInterval;
}

/** The Stripe Checkout URL to redirect the browser to. */
export interface CheckoutSessionResponse {
  url: string;
}

/** The Stripe billing-portal URL to redirect the browser to. */
export interface PortalSessionResponse {
  url: string;
}
