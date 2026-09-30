"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { HeroMetricCard } from "@/components/data/HeroMetricCard";
import { MacroRing } from "@/components/data/MacroRing";
import type { DashboardData } from "../useDashboardData";

/** W1.1 shell for the calorie hero + macro row — the pre-redesign cards,
 *  moved unchanged into their slot; `CalorieHero` (W1.2) replaces it. */
export function HeroSection({ data }: { data: DashboardData }) {
  const t = useTranslations("dashboard");
  const { settings, totals } = data;

  return (
    <div className="flex flex-col gap-4">
      <HeroMetricCard value={totals.kcal} goal={settings?.dailyCalorieGoal} />

      {!settings?.dailyCalorieGoal && !settings?.dailyProteinGoal && (
        <Link href="/settings" className="text-sm font-semibold -mt-2 hover:underline" style={{ color: "var(--primary)" }}>
          {t("setGoalsHint")}
        </Link>
      )}

      <div className="grid grid-cols-3 gap-4">
        {(
          [
            ["protein", totals.protein, settings?.dailyProteinGoal, "var(--metric-protein)"],
            ["carbs", totals.carbs, settings?.dailyCarbsGoal, "var(--metric-carbs)"],
            ["fat", totals.fat, settings?.dailyFatGoal, "var(--metric-fat)"],
          ] as const
        ).map(([key, value, goal, color]) => (
          <div key={key} className="rounded-[var(--r-card)] p-4 flex justify-center" style={{ background: "var(--surface)" }}>
            <MacroRing label={t(key)} value={value} goal={goal} color={color} />
          </div>
        ))}
      </div>
    </div>
  );
}
