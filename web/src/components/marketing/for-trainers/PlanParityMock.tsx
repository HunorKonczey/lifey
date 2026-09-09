import { Fragment } from "react";
import { getTranslations } from "next-intl/server";
import { PLANS } from "@/lib/pricing";

/**
 * No screenshot exists for "every tier has every feature" — it's a fact
 * about pricing, not a screen. Reproduces the pricing card's own chip/check
 * vocabulary (PricingPreview.tsx) at a smaller scale rather than a second,
 * competing pricing-card layout, since the real pricing cards render two
 * sections down this same page (68 D-DW1: reproduced UI, not illustration).
 */
export async function PlanParityMock() {
  const t = await getTranslations("forTrainers.block4");

  const names: Record<string, string> = {
    starter: t("planStarter"),
    pro: t("planPro"),
    studio: t("planStudio"),
  };

  const features = [t("featureProgram"), t("featureChat"), t("featureReport")];

  return (
    <div
      className="rounded-lg border border-outline p-5 md:p-6"
      style={{ background: "var(--surface)", boxShadow: "0 24px 60px rgba(0,0,0,.25)" }}
    >
      {/*
        One grid for the whole card, not a separate chip row + loose
        checkmark rows — the two were never actually column-aligned (the
        chips split the full width into 3 equal thirds; each checkmark row
        below had a text label eating into that same width first), so a
        checkmark's plan was only inferable by counting position. `auto`
        columns size every row's cells in that column to the same width,
        so a plan's chip and every one of its checkmarks now share a
        column for real, not just visually near each other.
      */}
      <div className="grid grid-cols-[1fr_auto_auto_auto] gap-x-2.5 gap-y-2.5 items-center">
        <div />
        {PLANS.map((plan) => (
          <div
            key={plan.id}
            className="rounded-md px-3 py-2.5 text-center"
            style={{
              background: "var(--surface-container)",
              border: plan.recommended ? "1.5px solid var(--primary)" : undefined,
            }}
          >
            <div className="text-[10px] font-extrabold" style={{ color: "var(--muted)" }}>
              {names[plan.id].toUpperCase()}
            </div>
            <div className="text-lg font-extrabold tabular-nums mt-0.5">{plan.seats ?? t("unlimited")}</div>
          </div>
        ))}

        {features.map((feature) => (
          <Fragment key={feature}>
            <span className="text-[12.5px] font-bold">{feature}</span>
            {PLANS.map((plan) => (
              <span
                key={plan.id}
                className="material-symbols-rounded text-lg justify-self-center"
                style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}
              >
                check_circle
              </span>
            ))}
          </Fragment>
        ))}
      </div>

      <div
        className="rounded-md p-2.5 mt-3.5 text-[11.5px] leading-[1.5] text-center"
        style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
      >
        {t("mockNote")}
      </div>
    </div>
  );
}
