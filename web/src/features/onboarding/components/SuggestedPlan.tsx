"use client";

import { useTranslations } from "next-intl";
import { useFormat } from "@/lib/format/useFormat";
import { planSentence } from "../planSentence";
import type { SuggestGoalsResponse } from "../types";

/**
 * The suggested-plan hero (W6-D): the calorie number big, one sentence saying what it means against what the person
 * burns, then the four other targets as tiles. Every figure is the backend's `SuggestGoalsResponse`, formatted.
 */
export function SuggestedPlan({ plan }: { plan: SuggestGoalsResponse }) {
  const t = useTranslations("onboarding");
  const d = useTranslations("dashboard");
  const fmt = useFormat();
  const sentence = planSentence(plan);
  const macros = [
    { label: d("protein"), value: fmt.number(plan.proteinGrams), unit: "g", color: "var(--m-protein)" },
    { label: d("carbs"), value: fmt.number(plan.carbsGrams), unit: "g", color: "var(--m-carbs)" },
    { label: d("fat"), value: fmt.number(plan.fatGrams), unit: "g", color: "var(--m-fat)" },
    { label: d("water"), value: fmt.number(plan.waterLiters, 1), unit: "L", color: "var(--m-water)" },
  ];
  return (
    <div className="flex flex-col gap-5" data-testid="suggested-plan">
      <div className="flex flex-col gap-3 p-6" style={{ borderRadius: "var(--r-card)", background: "var(--card)" }}>
        <span className="type-body-s" style={{ color: "var(--m-kcal)", fontWeight: 700 }}>{t("planHeroKicker")}</span>
        <span className="num" style={{ fontSize: 56, lineHeight: 1, fontWeight: 800, letterSpacing: "-0.03em" }}>
          {fmt.number(plan.calories)} <span style={{ fontSize: 22, fontWeight: 700, color: "var(--text-2)", letterSpacing: 0 }}>kcal</span>
        </span>
        <p className="type-body" style={{ color: "var(--text-2)" }}>
          {t(`planHero_${sentence.kind}`, { calories: fmt.number(plan.calories), gap: fmt.number(sentence.gap), tdee: fmt.number(plan.tdee) })}
        </p>
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3" aria-label={t("planHeroMacros")}>
        {macros.map((m) => (
          <div key={m.label} className="flex flex-col gap-1 p-4" style={{ borderRadius: "var(--r-card)", background: "var(--nested)" }}>
            <span className="type-body-s" style={{ color: m.color, fontWeight: 700 }}>{m.label}</span>
            <span className="num" style={{ fontSize: 24, fontWeight: 800 }}>
              {m.value} <span className="type-body-s" style={{ color: "var(--text-2)" }}>{m.unit}</span>
            </span>
          </div>
        ))}
      </div>
      <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("suggestedFrom", { bmr: fmt.number(plan.bmr), tdee: fmt.number(plan.tdee) })}</p>
    </div>
  );
}
