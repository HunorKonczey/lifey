"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useCheckoutConfirmation, useEntitlements, type CheckoutConfirmationStatus } from "@/features/billing/hooks";
import { consumePendingCheckoutPlan } from "@/features/billing/checkoutPoll";
import { billingApi } from "@/features/billing/api";
import { daysUntil, statusPillFor, trialElapsedFraction, type StatusPillTone } from "@/features/billing/status";
import type { SubscriptionStatus, TrainerPlan } from "@/features/billing/types";
import { SeatMeter } from "@/features/billing/components/SeatMeter";
import { PlanChooser } from "@/features/billing/components/PlanChooser";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { Button, Card, Icon, TintedChip } from "@/components/ds";
import { RatioBar } from "@/components/ds/progress/RatioBar";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { useFormat } from "@/lib/i18n/format";

const PILL_COLORS: Record<StatusPillTone, string> = {
  trial: "var(--m-carbs)",
  active: "var(--primary)",
  warning: "var(--heart)",
  error: "var(--heart)",
  muted: "var(--text-2)",
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
  const fmt = useFormat();
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
  const trialDaysLeft = trainer?.status === "TRIALING" && trainer.trialEndsAt ? daysUntil(entitlement.checkedAt, trainer.trialEndsAt) : null;

  return (
    <div className="flex max-w-3xl flex-col gap-4">
      {showCancelNotice && (
        <Card variant="nested" data-testid="checkout-cancel-notice">
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("checkoutCanceledNotice")}</p>
        </Card>
      )}

      {checkoutActive && checkoutStatus !== "confirmed" && (
        <CheckoutStatusBanner status={checkoutStatus} onRefresh={manualRefresh} refreshing={manualCheckPending} />
      )}

      {!suppressNormalContent && (
        <>
          <Card className="flex flex-col gap-3">
            {trainer?.status ? (
              <>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    <p className="type-overline" style={{ color: "var(--text-3)" }}>{t("currentPlanOverline")}</p>
                    <p data-testid="current-plan-name" style={{ fontSize: 20, fontWeight: 800 }}>
                      {trainer.plan ? t(PLAN_NAME_KEYS[trainer.plan]) : t("noPlan")}
                    </p>
                  </div>
                  <StatusPill status={trainer.status} trialEndsAt={trainer.trialEndsAt} checkedAt={entitlement.checkedAt} />
                </div>
                {trialDaysLeft != null ? (
                  // trainer.trialEndsAt is always populated for a TRIALING row, even
                  // when lifey.billing.enabled=false forces the top-level expiresAt to
                  // null (openResponse, 64 §1 point 6 rollback switch).
                  <div className="flex flex-col gap-2" data-testid="trial-progress">
                    <p className="type-body-s" style={{ color: "var(--text-2)" }}>
                      {t("trialDaysLeft", { days: trialDaysLeft })}
                    </p>
                    <RatioBar segments={[{ value: trialElapsedFraction(trialDaysLeft), color: "var(--m-carbs)" }]} total={1} />
                    <p className="type-body-s" style={{ color: "var(--text-3)" }}>
                      {t("trialEndsOn", { date: fmt.date(trainer.trialEndsAt!, "dayYear") })}
                    </p>
                  </div>
                ) : (
                  trainer.status !== "TRIALING" &&
                  entitlement.expiresAt && (
                    <p className="type-body-s" style={{ color: "var(--text-3)" }}>
                      {t("renewsOn", { date: fmt.date(entitlement.expiresAt, "dayYear") })}
                    </p>
                  )
                )}
              </>
            ) : (
              <p className="type-body" style={{ color: "var(--text-2)" }}>{t("noSubscriptionYet")}</p>
            )}
          </Card>

          <SeatMeter
            activeClients={trainer?.activeClients ?? 0}
            maxClients={trainer?.maxClients ?? null}
            pendingCount={pendingInvites?.length ?? 0}
          />

          <PlanChooser currentPlan={trainer?.plan ?? null} />

          <Card className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="type-body" style={{ fontWeight: 800 }}>{t("manageBillingTitle")}</h2>
              <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("manageBillingBody")}</p>
            </div>
            <Button
              variant="secondary"
              onClick={() => {
                setPortalError(null);
                portalMutation.mutate();
              }}
              disabled={portalMutation.isPending}
            >
              {t("manageBillingCta")}
            </Button>
          </Card>
          {portalError && (
            <p className="type-body-s" style={{ color: "var(--heart)" }}>{portalError}</p>
          )}

          <Card variant="nested">
            <h2 className="type-body mb-2" style={{ fontWeight: 800 }}>{t("cancelExplainerTitle")}</h2>
            <ul className="type-body-s flex flex-col gap-1.5" style={{ color: "var(--text-2)" }}>
              <li>{t("cancelExplainerClientsKeepData")}</li>
              <li>{t("cancelExplainerChatKeepsWorking")}</li>
              <li>{t("cancelExplainerReadAccess")}</li>
              <li>{t("cancelExplainerNoNewInvites")}</li>
            </ul>
          </Card>
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
    <Card data-testid={polling ? "checkout-activating-banner" : "checkout-timedout-banner"} className="flex items-start gap-3">
      <Icon name={polling ? "hourglass_top" : "info"} size={24} color="var(--primary)" />
      <div className="flex-1">
        <p className="type-body" style={{ fontWeight: 800 }}>{polling ? t("checkoutActivatingTitle") : t("checkoutTimedOutTitle")}</p>
        <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }}>{polling ? t("checkoutActivatingBody") : t("checkoutTimedOutBody")}</p>
        {!polling && (
          <Button className="mt-3" variant="secondary" onClick={onRefresh} disabled={refreshing}>
            {refreshing ? t("checkoutRefreshing") : t("checkoutRefresh")}
          </Button>
        )}
      </div>
    </Card>
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

  return <TintedChip label={label} color={PILL_COLORS[pill.tone]} />;
}
