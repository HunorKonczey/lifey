"use client";

import { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { queryKeys } from "@/lib/api/queryKeys";
import { billingApi } from "./api";
import { nextCheckoutPollDelayMs } from "./checkoutPoll";
import { trainerBillingStateFor } from "./billingGate";
import type { TrainerPlan } from "./types";

/**
 * The one entitlement read every billing-aware screen uses
 * (docs/landing_page/66-trainer-billing-web-plan.md §6). 60s `staleTime`
 * matches the backend's own `Cache-Control: max-age=60` on this endpoint —
 * refetching sooner than the server itself considers the value fresh would
 * just be a wasted round trip. `refetchOnWindowFocus` is TanStack Query's
 * default (true) — spelled out here because this is the one query in the app
 * where that default actually matters: a trainer coming back from Stripe's
 * hosted checkout/portal in another tab needs the next focus to pick up
 * whatever the webhook already recorded (64 D-B5), not wait a minute.
 */
export function useEntitlements() {
  return useQuery({
    queryKey: queryKeys.billing.entitlements(),
    queryFn: billingApi.entitlements,
    staleTime: 60_000,
    refetchOnWindowFocus: true,
  });
}

export type CheckoutConfirmationStatus = "polling" | "confirmed" | "timedOut";

function isConfirmed(
  data: ReturnType<typeof useEntitlements>["data"],
  expectedPlan: TrainerPlan | null,
): boolean {
  return expectedPlan ? data?.trainer?.plan === expectedPlan : data?.trainer?.status === "ACTIVE";
}

/**
 * D-T3's "activating your plan…" poll after a Stripe Checkout redirect back
 * (66 §3) — 1s, backing off, 30s ceiling (checkoutPoll.ts), until the plan
 * actually changes. It never trusts the redirect itself (64 D-B5): `active`
 * only starts the loop, `expectedPlan` (captured client-side the moment the
 * trainer clicked a plan in `PlanChooser`, before the full-page redirect to
 * Stripe wipes React state) is what the fetched entitlement has to match
 * before this reports `"confirmed"`. Falls back to "status is ACTIVE" when
 * `expectedPlan` is unknown (e.g. a stale/bookmarked `?checkout=success` URL).
 *
 * A plain `setTimeout` loop, not TanStack Query's `refetchInterval` — the
 * stop condition depends on the *fetched value*, and `manualRefresh` (the
 * "refresh" D-T3 offers once timed out) needs to run a single one-off check
 * without restarting the whole schedule, which is simpler to reason about as
 * an explicit loop than coordinating with the query's own refetch scheduling.
 */
export function useCheckoutConfirmation(active: boolean, expectedPlan: TrainerPlan | null) {
  const { data: entitlement, refetch } = useEntitlements();
  const [status, setStatus] = useState<CheckoutConfirmationStatus>("polling");
  const [manualCheckPending, setManualCheckPending] = useState(false);
  const attemptRef = useRef(0);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!active) return;
    let cancelled = false;
    attemptRef.current = 0;
    // No synchronous setStatus("polling") reset here — the initial useState
    // value above already is "polling", and `active`/`expectedPlan` are
    // locked once per page load by the caller (lazy useState initializers in
    // page.tsx), so this effect only ever runs once in practice.

    async function poll() {
      const { data } = await refetch();
      if (cancelled) return;
      if (isConfirmed(data, expectedPlan)) {
        setStatus("confirmed");
        return;
      }
      const delay = nextCheckoutPollDelayMs(attemptRef.current);
      attemptRef.current += 1;
      if (delay === false) {
        setStatus("timedOut");
        return;
      }
      timeoutRef.current = setTimeout(poll, delay);
    }
    void poll();

    return () => {
      cancelled = true;
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [active, expectedPlan, refetch]);

  async function manualRefresh() {
    setManualCheckPending(true);
    const { data } = await refetch();
    setManualCheckPending(false);
    if (isConfirmed(data, expectedPlan)) setStatus("confirmed");
  }

  return { entitlement, status, manualCheckPending, manualRefresh };
}

/**
 * D-T5's pre-check for the four gated actions (send invite, assign content,
 * assign a program, schedule a workout) — one hook so `BillingBlockedDialog`'s
 * three data props (`currentPlan`, `activeClients`, `maxClients`) always come
 * from the same place `AdminBillingBanner` and `/admin/billing` already read,
 * never re-fetched or re-derived per call site.
 */
export function useTrainerBillingGate() {
  const { data: entitlement } = useEntitlements();
  return {
    state: trainerBillingStateFor(entitlement),
    currentPlan: entitlement?.trainer?.plan ?? null,
    activeClients: entitlement?.trainer?.activeClients ?? 0,
    maxClients: entitlement?.trainer?.maxClients ?? null,
  };
}
