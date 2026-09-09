/**
 * D-T3 (docs/landing_page/66-trainer-billing-web-plan.md §3): "polls GET
 * /api/v1/me/entitlements (1 s, backing off, 30 s ceiling) until the plan
 * changes." A fixed schedule rather than a formula — early polls are frequent
 * since most webhooks land within a couple of seconds (64 §5.4), later ones
 * back off instead of hammering the endpoint for a wait that's probably
 * already lost. Cumulative elapsed time after each entry: 1, 2, 4, 7, 12, 20,
 * 30 (seconds) — the last entry lands exactly on the 30 s ceiling.
 */
const POLL_DELAYS_MS = [1000, 1000, 2000, 3000, 5000, 8000, 10000] as const;

export const CHECKOUT_POLL_CEILING_MS = 30_000;

/**
 * @param attempt 0-based poll count so far.
 * @returns the delay before the next poll, or `false` once the 30 s ceiling is reached.
 */
export function nextCheckoutPollDelayMs(attempt: number): number | false {
  if (attempt < 0 || attempt >= POLL_DELAYS_MS.length) return false;
  return POLL_DELAYS_MS[attempt];
}

/**
 * Which plan the trainer selected, captured just before `PlanChooser`
 * redirects to Stripe — the full-page redirect wipes React state, so this is
 * the only way `/admin/billing?checkout=success` later knows which plan the
 * poll is waiting for. `sessionStorage`, not a URL param: Stripe's own
 * `success_url` is a fixed value configured server-side (`StripeProperties
 * .successUrl`), not something the frontend can parameterize per checkout.
 */
const PENDING_PLAN_KEY = "lifey-billing-pending-plan";

export function setPendingCheckoutPlan(plan: string): void {
  try {
    sessionStorage.setItem(PENDING_PLAN_KEY, plan);
  } catch {
    /* private browsing / storage disabled — the poll just falls back to the ACTIVE-status check */
  }
}

/** One-shot read: clears the stored value so a later, unrelated `?checkout=success` visit doesn't reuse a stale plan. */
export function consumePendingCheckoutPlan(): string | null {
  try {
    const value = sessionStorage.getItem(PENDING_PLAN_KEY);
    sessionStorage.removeItem(PENDING_PLAN_KEY);
    return value;
  } catch {
    return null;
  }
}
