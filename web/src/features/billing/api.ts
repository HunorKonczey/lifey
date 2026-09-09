import { api } from "@/lib/api/client";
import type {
  CheckoutSessionRequest,
  CheckoutSessionResponse,
  EntitlementResponse,
  PortalSessionResponse,
} from "./types";

export const billingApi = {
  /**
   * GET /api/v1/me/entitlements — never 404/5xx for a business reason (64 §3.1).
   *
   * `cache: "no-store"` is deliberate: the backend answers with `Cache-Control:
   * private, max-age=60` so a plain page load doesn't recompute this on every
   * request, but the browser's own HTTP cache doesn't know about (or respect)
   * `queryClient.invalidateQueries()` — it happily serves the 60s-old cached
   * response to a `fetch()` triggered *by* that invalidation, silently
   * defeating it. `useEntitlements()`'s own `staleTime: 60_000` already gives
   * the "don't hit the network more than once a minute in normal use" behavior
   * at the TanStack Query layer, correctly — unlike the HTTP cache — respecting
   * an explicit invalidation, so this is the only layer that needs the header
   * honored, and the HTTP-cache layer must be bypassed entirely. Found by
   * Prompt 9's archiving flow: the seat count banner never moved after
   * archiving a client, staying stuck at the pre-archive count for up to a
   * full minute — exactly the "seat meter shows a stale number" failure 66 §9
   * risk 1 warns about, just from an HTTP-cache cause rather than a missing
   * `invalidateQueries` call.
   */
  entitlements: () => api.get<EntitlementResponse>("/me/entitlements", { cache: "no-store" }),
  /** ROLE_TRAINER only; returns a Stripe Checkout URL to redirect to (64 §5.2). */
  checkoutSession: (body: CheckoutSessionRequest) =>
    api.post<CheckoutSessionResponse>("/billing/checkout-session", body),
  /** ROLE_TRAINER only; returns a Stripe billing-portal URL to redirect to (64 §5.2). */
  portalSession: () => api.post<PortalSessionResponse>("/billing/portal-session"),
};
