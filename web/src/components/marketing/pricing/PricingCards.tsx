"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { track } from "@vercel/analytics";
import { useSessionStore } from "@/features/auth/store";
import { formatHuf, monthlyEquivalent, type PlanId } from "@/lib/pricing";

/**
 * The interval toggle (65 §5.1/§5.2) needs client state, and the CTA swap
 * for a signed-in visitor (65 §10 edge case 1: "must see a CTA that goes to
 * `/admin/billing`, not `/register`") needs the session store — so this one
 * piece of the pricing page is a client island, unlike the fully-static
 * home and for-trainers pages (65 Prompts 4–5). Everything plan-specific
 * that doesn't change with the toggle (names, bullets, seat labels) is
 * resolved server-side in page.tsx and passed in already translated —
 * matching MarketingNav/HeaderAuthActions' "labels as props" pattern (the
 * locale-only NextIntlClientProvider carries no `messages`, so a client
 * component can't call `useTranslations` itself).
 *
 * Only the CTA *text and destination* swap for a signed-in visitor — there
 * is no entitlement data on the frontend yet to know which plan they're on,
 * so the canvas's "jelenlegi csomagod" per-card tag is not implemented here
 * (65 Prompt 6 landed notes; that needs `66`'s billing backend).
 */
export function PricingCards({
  plans,
  labels,
  billingHref,
}: {
  plans: {
    id: PlanId;
    name: string;
    seats: string | null;
    unlimitedLabel: string;
    activeClientsLabel: string;
    yearlyPriceHuf: number;
    monthlyPriceHuf: number;
    bullets: string[];
    recommended: boolean;
  }[];
  labels: {
    toggleMonthly: string;
    toggleYearly: string;
    toggleYearlyBadge: string;
    toggleYearlyBadgeMobile: string;
    perYear: string;
    perMonth: string;
    perMonthSuffix: string;
    billedMonthlyPrefix: string;
    trialBadge: string;
    recommendedBadge: string;
    planCta: string;
    managePlanCta: string;
  };
  billingHref: string;
}) {
  const [yearly, setYearly] = useState(true);
  const { user, initialize } = useSessionStore();

  useEffect(() => {
    initialize();
  }, [initialize]);

  // pricing_view (65 §7: "do people flip to yearly") — fires once on mount
  // with the default interval, and again on every toggle.
  useEffect(() => {
    track("pricing_view", { interval: yearly ? "yearly" : "monthly" });
  }, [yearly]);

  return (
    <div>
      <div className="flex justify-center">
        <div
          className="inline-flex items-center gap-1 rounded-pill p-1.5"
          style={{ background: "var(--surface-container)" }}
        >
          <button
            type="button"
            onClick={() => setYearly(false)}
            className="h-11 px-5 rounded-pill text-sm font-bold"
            style={!yearly ? { background: "var(--primary)", color: "var(--bg)" } : { color: "var(--on-surface-variant)" }}
          >
            {labels.toggleMonthly}
          </button>
          <button
            type="button"
            onClick={() => setYearly(true)}
            className="h-11 px-5 rounded-pill text-sm font-extrabold flex items-center gap-2"
            style={yearly ? { background: "var(--primary)", color: "var(--bg)" } : { color: "var(--on-surface-variant)" }}
          >
            {labels.toggleYearly}
            <span
              className="rounded-pill px-2 py-0.5 text-[11px] font-extrabold"
              style={{ background: "var(--bg)", color: "var(--primary)" }}
            >
              <span className="hidden md:inline">{labels.toggleYearlyBadge}</span>
              <span className="md:hidden">{labels.toggleYearlyBadgeMobile}</span>
            </span>
          </button>
        </div>
      </div>

      <div className="grid md:grid-cols-3 gap-5 mt-11">
        {plans.map((plan) => {
          const ctaHref = user ? billingHref : `/register?src=pricing-${plan.id}`;
          const ctaLabel = user ? labels.managePlanCta : labels.planCta;

          return (
            <div
              key={plan.id}
              className="rounded-lg p-8 relative"
              style={{
                background: "var(--surface-container)",
                border: plan.recommended ? "2px solid var(--primary)" : "1px solid var(--outline)",
                boxShadow: plan.recommended ? "0 8px 32px rgba(0,0,0,.18)" : undefined,
              }}
            >
              {plan.recommended && (
                <div
                  className="absolute -top-3 left-8 h-6.5 flex items-center px-3 rounded-pill text-[11.5px] font-extrabold tracking-wide"
                  style={{ background: "var(--primary)", color: "var(--bg)" }}
                >
                  {labels.recommendedBadge.toUpperCase()}
                </div>
              )}

              <div className="text-[13px] font-extrabold tracking-wide" style={{ color: plan.recommended ? "var(--primary)" : "var(--muted)" }}>
                {plan.name.toUpperCase()}
              </div>
              <div className="text-[44px] font-extrabold tracking-[-0.02em] tabular-nums mt-3.5">
                {plan.seats ?? plan.unlimitedLabel}
              </div>
              <div className="text-base font-bold" style={{ color: "var(--on-surface-variant)" }}>
                {plan.activeClientsLabel}
              </div>

              <div className="h-px my-5.5" style={{ background: "var(--outline)" }} />

              {yearly ? (
                <>
                  <div className="text-2xl font-extrabold tabular-nums">
                    {formatHuf(plan.yearlyPriceHuf)}
                    <span className="text-sm font-semibold" style={{ color: "var(--muted)" }}> {labels.perYear}</span>
                  </div>
                  <div className="text-[13.5px] tabular-nums mt-1" style={{ color: "var(--muted)" }}>
                    {formatHuf(monthlyEquivalent(plan.yearlyPriceHuf))} {labels.perMonthSuffix} · {labels.billedMonthlyPrefix}{" "}
                    {formatHuf(plan.monthlyPriceHuf)}
                  </div>
                </>
              ) : (
                <div className="text-2xl font-extrabold tabular-nums">
                  {formatHuf(plan.monthlyPriceHuf)}
                  <span className="text-sm font-semibold" style={{ color: "var(--muted)" }}> {labels.perMonth}</span>
                </div>
              )}

              <div
                className="h-13 flex items-center justify-center rounded-pill text-sm font-bold mt-5.5"
                style={
                  plan.recommended
                    ? { background: "var(--primary)", color: "var(--bg)", fontWeight: 800 }
                    : { border: "1.5px solid var(--outline)" }
                }
              >
                {labels.trialBadge}
              </div>

              <ul className="flex flex-col gap-2.5 mt-5.5">
                {plan.bullets.map((b) => (
                  <li key={b} className="flex gap-2.5 items-start text-[14.5px]">
                    <span
                      className="material-symbols-rounded text-lg mt-0.5"
                      style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}
                    >
                      check_circle
                    </span>
                    {b}
                  </li>
                ))}
              </ul>

              <Link
                href={ctaHref}
                className="flex h-13 items-center justify-center rounded-pill text-sm font-extrabold mt-6"
                style={
                  plan.recommended
                    ? { background: "var(--primary)", color: "var(--bg)" }
                    : { border: "1.5px solid var(--outline)" }
                }
                onClick={() =>
                  track("pricing_plan_click", { plan: plan.id, interval: yearly ? "yearly" : "monthly" })
                }
              >
                {ctaLabel}
              </Link>
            </div>
          );
        })}
      </div>
    </div>
  );
}
