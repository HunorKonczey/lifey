"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { useCheckoutConfirmation, useEntitlements, type CheckoutConfirmationStatus } from "@/features/billing/hooks";
import { consumePendingCheckoutPlan } from "@/features/billing/checkoutPoll";
import { billingApi } from "@/features/billing/api";
import { daysUntil, statusPillFor, type StatusPillTone } from "@/features/billing/status";
import type { SubscriptionStatus, TrainerPlan } from "@/features/billing/types";
import { SeatMeter } from "@/features/billing/components/SeatMeter";
import { PlanChooser } from "@/features/billing/components/PlanChooser";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";

const PILL_STYLES: Record<StatusPillTone, { background: string; color: string }> = {
  trial: { background: "var(--tertiary-container)", color: "var(--on-tertiary-container)" },
  active: { background: "var(--tertiary-container)", color: "var(--on-tertiary-container)" },
  warning: { background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" },
  error: { background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" },
  muted: { background: "var(--surface-highest)", color: "var(--on-surface-variant)" },
};

const PLAN_NAME_KEYS = { STARTER: "planStarter", PRO: "planPro", STUDIO: "planStudio" } as const;

/**
 * docs/landing_page/66-trainer-billing-web-plan.md §3 — current plan card,
 * seat meter, plan chooser, manage-billing button, cancel explainer, plus
 * (`66` Prompt 6) the `?checkout=success`/`?checkout=cancel` round trip
 * (D-T3): the redirect back from Stripe is a UI convenience only, never
 * trusted on its own (64 D-B5) — the page polls entitlements and only shows
 * the new plan once the fetched response actually confirms it.
 */
export default function AdminBillingPage() {
  const t = useTranslations("admin.billing");
  const router = useRouter();
  const searchParams = useSearchParams();
  const checkoutParam = searchParams.get("checkout");
  const [portalError, setPortalError] = useState<string | null>(null);

  // Lazy initializers, not an effect: these only need to capture the *first*
  // render's URL/sessionStorage state once and then latch — `checkoutParam`
  // itself changes on the next render, right after the effect below strips
  // it from the URL, and an in-progress poll must not stop just because the
  // URL that started it is gone.
  const [checkoutActive] = useState(() => checkoutParam === "success");
  const [expectedPlan] = useState<TrainerPlan | null>(() =>
    checkoutParam === "success" ? (consumePendingCheckoutPlan() as TrainerPlan | null) : null,
  );
  const [showCancelNotice] = useState(() => checkoutParam === "cancel");

  useEffect(() => {
    if (checkoutParam === "success" || checkoutParam === "cancel") {
      router.replace("/admin/billing");
    }
  }, [checkoutParam, router]);

  const {
    status: checkoutStatus,
    manualCheckPending,
    manualRefresh,
  } = useCheckoutConfirmation(checkoutActive, expectedPlan);
  const { data: entitlement, isLoading, isError, refetch } = useEntitlements();
  const { data: pendingInvites } = useQuery({
    queryKey: queryKeys.trainerInvites.all(),
    queryFn: trainerApi.pendingInvites,
  });

  const portalMutation = useMutation({
    mutationFn: billingApi.portalSession,
    onSuccess: (data) => {
      window.location.href = data.url;
    },
    onError: () => setPortalError(t("portalFailed")),
  });

  // D-T3: while polling, never render anything that could read as "the new
  // plan" — not even the stale current-plan card — until the fetch itself
  // confirms it. Once confirmed or timed out, the normal page (with whatever
  // the last successful fetch returned) renders as usual.
  const suppressNormalContent = checkoutActive && checkoutStatus === "polling";

  if (isLoading) {
    return (
      <div className="flex flex-col gap-3.5 max-w-3xl mx-auto">
        <Skeleton variant="card" />
        <Skeleton variant="card" />
      </div>
    );
  }

  if (isError || !entitlement) {
    return <ErrorState onRetry={refetch} />;
  }

  const trainer = entitlement.trainer;

  return (
    <div className="flex flex-col gap-3.5 max-w-3xl mx-auto">
      <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
        {t("title")}
      </p>

      {showCancelNotice && (
        <div
          data-testid="checkout-cancel-notice"
          className="rounded-[var(--r-lg)] p-3.5 text-xs"
          style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
        >
          {t("checkoutCanceledNotice")}
        </div>
      )}

      {checkoutActive && checkoutStatus !== "confirmed" && (
        <CheckoutStatusBanner status={checkoutStatus} onRefresh={manualRefresh} refreshing={manualCheckPending} />
      )}

      {!suppressNormalContent && (
        <>
          <div className="rounded-[var(--r-lg)] p-4.5" style={{ background: "var(--surface-container)" }}>
        {trainer?.status ? (
          <>
            <div className="flex items-center justify-between gap-2 flex-wrap">
              <p data-testid="current-plan-name" className="text-base font-extrabold" style={{ color: "var(--on-surface)" }}>
                {trainer.plan ? t(PLAN_NAME_KEYS[trainer.plan]) : t("noPlan")}
              </p>
              <StatusPill status={trainer.status} trialEndsAt={trainer.trialEndsAt} checkedAt={entitlement.checkedAt} />
            </div>
            {trainer.status === "TRIALING" && trainer.trialEndsAt ? (
              // trainer.trialEndsAt is always populated for a TRIALING row, even
              // when lifey.billing.enabled=false forces the top-level expiresAt to
              // null (openResponse, 64 §1 point 6's rollback switch) — found only
              // by actually checking this in a browser against the real (disabled-
              // by-default) local backend, not from the type-checker or a unit test.
              <p className="text-xs mt-1.5" style={{ color: "var(--on-surface-variant)" }}>
                {t("trialEndsOn", { date: format(new Date(trainer.trialEndsAt), "yyyy-MM-dd") })}
              </p>
            ) : (
              trainer.status !== "TRIALING" &&
              entitlement.expiresAt && (
                <p className="text-xs mt-1.5" style={{ color: "var(--on-surface-variant)" }}>
                  {t("renewsOn", { date: format(new Date(entitlement.expiresAt), "yyyy-MM-dd") })}
                </p>
              )
            )}
          </>
        ) : (
          <p className="text-sm" style={{ color: "var(--on-surface-variant)" }}>
            {t("noSubscriptionYet")}
          </p>
        )}
      </div>

      <SeatMeter
        activeClients={trainer?.activeClients ?? 0}
        maxClients={trainer?.maxClients ?? null}
        pendingCount={pendingInvites?.length ?? 0}
      />

      <PlanChooser currentPlan={trainer?.plan ?? null} />

      <div
        className="rounded-[var(--r-lg)] p-4.5 flex items-center justify-between gap-3 flex-wrap"
        style={{ background: "var(--surface-container)" }}
      >
        <div>
          <p className="text-sm font-extrabold" style={{ color: "var(--on-surface)" }}>
            {t("manageBillingTitle")}
          </p>
          <p className="text-xs mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("manageBillingBody")}
          </p>
        </div>
        <button
          onClick={() => {
            setPortalError(null);
            portalMutation.mutate();
          }}
          disabled={portalMutation.isPending}
          className="shrink-0 h-11 px-5 rounded-pill text-sm font-bold border-[1.5px] border-outline disabled:opacity-50"
        >
          {t("manageBillingCta")}
        </button>
      </div>
      {portalError && (
        <p className="text-xs" style={{ color: "var(--error)" }}>
          {portalError}
        </p>
      )}

          <div className="rounded-[var(--r-lg)] p-4.5" style={{ background: "var(--surface)" }}>
            <p className="text-sm font-extrabold mb-2" style={{ color: "var(--on-surface)" }}>
              {t("cancelExplainerTitle")}
            </p>
            <ul className="flex flex-col gap-1.5 text-xs" style={{ color: "var(--on-surface-variant)" }}>
              <li>{t("cancelExplainerClientsKeepData")}</li>
              <li>{t("cancelExplainerChatKeepsWorking")}</li>
              <li>{t("cancelExplainerReadAccess")}</li>
              <li>{t("cancelExplainerNoNewInvites")}</li>
            </ul>
          </div>
        </>
      )}
    </div>
  );
}

function CheckoutStatusBanner({
  status,
  onRefresh,
  refreshing,
}: {
  status: CheckoutConfirmationStatus;
  onRefresh: () => void;
  refreshing: boolean;
}) {
  const t = useTranslations("admin.billing");
  const polling = status === "polling";

  return (
    <div
      data-testid={polling ? "checkout-activating-banner" : "checkout-timedout-banner"}
      className="rounded-[var(--r-lg)] p-4.5 flex items-start gap-3"
      style={{ background: "var(--tertiary-container)" }}
    >
      <span
        className="material-symbols-rounded text-2xl shrink-0"
        style={{ color: "var(--on-tertiary-container)" }}
      >
        {polling ? "hourglass_top" : "info"}
      </span>
      <div className="flex-1">
        <p className="text-sm font-extrabold" style={{ color: "var(--on-tertiary-container)" }}>
          {polling ? t("checkoutActivatingTitle") : t("checkoutTimedOutTitle")}
        </p>
        <p className="text-xs mt-1" style={{ color: "var(--on-tertiary-container)" }}>
          {polling ? t("checkoutActivatingBody") : t("checkoutTimedOutBody")}
        </p>
        {!polling && (
          <button
            onClick={onRefresh}
            disabled={refreshing}
            className="mt-2.5 h-9 px-4 rounded-pill text-xs font-extrabold disabled:opacity-50"
            style={{ background: "var(--on-tertiary-container)", color: "var(--tertiary-container)" }}
          >
            {refreshing ? t("checkoutRefreshing") : t("checkoutRefresh")}
          </button>
        )}
      </div>
    </div>
  );
}

function StatusPill({
  status,
  trialEndsAt,
  checkedAt,
}: {
  status: SubscriptionStatus;
  trialEndsAt: string | null;
  checkedAt: string;
}) {
  const t = useTranslations("admin.billing");
  const pill = statusPillFor(status);
  const label =
    pill.tone === "trial" && trialEndsAt
      ? t("statusTrialWithDays", { days: daysUntil(checkedAt, trialEndsAt) })
      : t(pill.labelKey);

  return (
    <span
      className="rounded-[var(--r-pill)] text-[11px] font-extrabold tracking-wide px-2.5 py-1"
      style={PILL_STYLES[pill.tone]}
    >
      {label}
    </span>
  );
}
