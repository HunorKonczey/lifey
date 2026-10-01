"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation } from "@tanstack/react-query";
import { Button, Card, SegmentedControl, TintedChip } from "@/components/ds";
import { formatHuf, monthlyEquivalent } from "@/lib/pricing";
import { billingApi } from "../api";
import { isCurrentPlan, planOptionsFor } from "../planPricing";
import { setPendingCheckoutPlan } from "../checkoutPoll";
import type { TrainerPlan } from "../types";

/**
 * The three tiers from the shared `PLANS` constant (65 D-W9/§10.4), current
 * plan marked, selecting one calls `POST /billing/checkout-session` and
 * redirects (66 §3 point 3). Deliberately its own component, not shared with
 * the marketing `/pricing` page's `PricingCards` — that one never triggers a
 * real checkout for a logged-in visitor, it only links here (see its own
 * comment); this is the first place that actually calls the endpoint.
 * W9-D look: DS card, monthly / yearly segmented control, tiles with the
 * current plan on the primary ring.
 */
export function PlanChooser({ currentPlan }: { currentPlan: TrainerPlan | null }) {
  const t = useTranslations("admin.billing");
  const [yearly, setYearly] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const checkoutMutation = useMutation({
    mutationFn: (plan: TrainerPlan) =>
      billingApi.checkoutSession({ plan, interval: yearly ? "YEARLY" : "MONTHLY" }),
    onSuccess: (data, plan) => {
      // D-T3: the redirect-back page needs to know which plan to poll for.
      setPendingCheckoutPlan(plan);
      window.location.href = data.url;
    },
    onError: () => setError(t("checkoutFailed")),
  });

  const options = planOptionsFor(yearly ? "YEARLY" : "MONTHLY");
  const names: Record<string, string> = {
    starter: t("planStarter"),
    pro: t("planPro"),
    studio: t("planStudio"),
  };

  return (
    <Card className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="type-body" style={{ fontWeight: 800 }}>{t("chooserTitle")}</h2>
        <SegmentedControl
          size="sm"
          aria-label={t("chooserTitle")}
          value={yearly ? "yearly" : "monthly"}
          onChange={(v) => setYearly(v === "yearly")}
          options={[
            { value: "monthly", label: t("toggleMonthly") },
            { value: "yearly", label: t("toggleYearly") },
          ]}
        />
      </div>

      <div className="grid gap-3 md:grid-cols-3">
        {options.map((option) => {
          const current = isCurrentPlan(option, currentPlan);
          return (
            <div
              key={option.id}
              data-testid="plan-chooser-card"
              data-plan={option.id}
              data-current={current}
              className="flex flex-col gap-1 p-4"
              style={{
                borderRadius: "var(--r-control)",
                background: current ? "color-mix(in srgb, var(--primary) 10%, var(--nested))" : "var(--nested)",
                boxShadow: current ? "inset 0 0 0 2px var(--primary)" : "none",
              }}
            >
              <p className="type-overline" style={{ color: "var(--text-3)" }}>{names[option.id]}</p>
              <p className="tabular" style={{ fontSize: 24, fontWeight: 800 }}>{option.seats ?? t("unlimitedSeats")}</p>
              <p className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>{t("activeClientsLabel")}</p>
              <div className="my-2 h-px" style={{ background: "var(--hairline)" }} />
              <p className="tabular" style={{ fontSize: 18, fontWeight: 800 }}>
                {formatHuf(option.priceHuf)}
                <span className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}> {yearly ? t("perYear") : t("perMonth")}</span>
              </p>
              {yearly && (
                <p className="type-body-s tabular" style={{ color: "var(--text-3)" }}>
                  {formatHuf(monthlyEquivalent(option.priceHuf))} {t("perMonth")}
                </p>
              )}

              <div className="mt-3">
                {current ? (
                  <TintedChip label={t("currentPlanBadge")} color="var(--primary)" size="medium" />
                ) : (
                  <Button
                    fullWidth
                    onClick={() => {
                      setError(null);
                      checkoutMutation.mutate(option.trainerPlan);
                    }}
                    disabled={checkoutMutation.isPending}
                  >
                    {t("selectPlan")}
                  </Button>
                )}
              </div>
            </div>
          );
        })}
      </div>
      {error && (
        <p className="type-body-s" style={{ color: "var(--heart)" }}>
          {error}
        </p>
      )}
    </Card>
  );
}
