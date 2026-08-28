"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation } from "@tanstack/react-query";
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
    <div className="rounded-[var(--r-lg)] p-4.5" style={{ background: "var(--surface-container)" }}>
      <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
        <p className="text-sm font-extrabold" style={{ color: "var(--on-surface)" }}>
          {t("chooserTitle")}
        </p>
        <div className="inline-flex items-center gap-1 rounded-pill p-1" style={{ background: "var(--surface-highest)" }}>
          <button
            type="button"
            onClick={() => setYearly(false)}
            className="h-8 px-3.5 rounded-pill text-xs font-bold"
            style={!yearly ? { background: "var(--primary)", color: "var(--bg)" } : { color: "var(--on-surface-variant)" }}
          >
            {t("toggleMonthly")}
          </button>
          <button
            type="button"
            onClick={() => setYearly(true)}
            className="h-8 px-3.5 rounded-pill text-xs font-bold"
            style={yearly ? { background: "var(--primary)", color: "var(--bg)" } : { color: "var(--on-surface-variant)" }}
          >
            {t("toggleYearly")}
          </button>
        </div>
      </div>

      <div className="grid md:grid-cols-3 gap-3">
        {options.map((option) => {
          const current = isCurrentPlan(option, currentPlan);
          return (
            <div
              key={option.id}
              data-testid="plan-chooser-card"
              data-plan={option.id}
              data-current={current}
              className="rounded-2xl p-4 flex flex-col"
              style={{
                background: "var(--surface)",
                border: current ? "2px solid var(--primary)" : "1px solid var(--outline)",
              }}
            >
              <p className="text-xs font-extrabold tracking-wide" style={{ color: "var(--muted)" }}>
                {names[option.id].toUpperCase()}
              </p>
              <p className="text-2xl font-extrabold tabular-nums mt-1.5">
                {option.seats ?? t("unlimitedSeats")}
              </p>
              <p className="text-xs font-bold" style={{ color: "var(--on-surface-variant)" }}>
                {t("activeClientsLabel")}
              </p>
              <div className="h-px my-3" style={{ background: "var(--outline)" }} />
              <p className="text-lg font-extrabold tabular-nums">
                {formatHuf(option.priceHuf)}
                <span className="text-xs font-semibold" style={{ color: "var(--muted)" }}>
                  {" "}
                  {yearly ? t("perYear") : t("perMonth")}
                </span>
              </p>
              {yearly && (
                <p className="text-[11px] tabular-nums mt-0.5" style={{ color: "var(--muted)" }}>
                  {formatHuf(monthlyEquivalent(option.priceHuf))} {t("perMonth")}
                </p>
              )}

              {current ? (
                <div
                  className="h-10 flex items-center justify-center rounded-pill text-xs font-extrabold mt-3.5"
                  style={{ background: "var(--tertiary-container)", color: "var(--on-tertiary-container)" }}
                >
                  {t("currentPlanBadge")}
                </div>
              ) : (
                <button
                  onClick={() => {
                    setError(null);
                    checkoutMutation.mutate(option.trainerPlan);
                  }}
                  disabled={checkoutMutation.isPending}
                  className="h-10 flex items-center justify-center rounded-pill text-xs font-extrabold mt-3.5 disabled:opacity-50"
                  style={{ background: "var(--primary)", color: "var(--bg)" }}
                >
                  {t("selectPlan")}
                </button>
              )}
            </div>
          );
        })}
      </div>
      {error && (
        <p className="text-xs mt-3" style={{ color: "var(--error)" }}>
          {error}
        </p>
      )}
    </div>
  );
}
