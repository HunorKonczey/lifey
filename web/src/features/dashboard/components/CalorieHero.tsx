"use client";

import { useCallback, useState, type ReactNode } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { AnimatedNumber, Button, Card, Icon, MetricBar, MetricValue, ProgressRing } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { usePageShortcuts } from "@/lib/hooks/usePageShortcuts";
import { AddFoodFlow } from "@/features/nutrition/components/addFood/AddFoodFlow";
import { isSameDay } from "@/components/ds/date/monthGrid";
import { heroState, macroRowState } from "../calorieHero";
import { CopyYesterdayButton } from "./CopyYesterdayButton";
import type { DashboardData } from "../useDashboardData";

const MACROS = [
  { key: "protein", color: "var(--metric-protein)" },
  { key: "carbs", color: "var(--metric-carbs)" },
  { key: "fat", color: "var(--metric-fat)" },
] as const;

export type MacroKey = (typeof MACROS)[number]["key"];

/** Ring diameter per width: the canvas' 220 at the 1440 frame, smaller where
 *  the hero shares the row with less room (1280), a touch larger when it
 *  spans the full width (1024), compact on a phone. */
function useRingSize(): number {
  const wide = useMediaQuery("(min-width: 1440px)");
  const desktop = useMediaQuery("(min-width: 1280px)");
  const tablet = useMediaQuery("(min-width: 640px)");
  if (wide) return 220;
  if (desktop) return 168;
  if (tablet) return 184;
  return 156;
}

export interface CalorieHeroViewProps {
  kcal: number;
  goalKcal: number | null;
  macros: Record<MacroKey, { value: number; goal: number | null }>;
  onAdd: () => void;
  /** The slot for W1.3's "copy yesterday's meal". */
  secondaryAction?: ReactNode;
  /** Shown when neither a calorie nor a protein goal exists. */
  showGoalsHint?: boolean;
}

/**
 * The dashboard's hero (W1.2, client-001): calories as a ring with the
 * remaining number at 56/800, eaten and goal beside it, three macro bars with
 * grams left, and the primary "add meal" action. The three states —
 * remaining, over budget (second lap, number = overage, the caption in
 * `--m-kcal`), and no calorie goal (empty ring, number = eaten, no goal line)
 * — come from `heroState`; a macro without a goal shows its value only. The
 * card itself is not a link; its buttons are the actions. Presentational, so
 * the gallery can show every state.
 */
export function CalorieHeroView({ kcal, goalKcal, macros, onAdd, secondaryAction, showGoalsHint }: CalorieHeroViewProps) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();
  const ringSize = useRingSize();

  const state = heroState(kcal, goalKcal);
  const over = state.mode === "over";
  const numberSize = ringSize >= 168 ? 56 : 40;
  const ringLabel = t("heroRingLabel", { eaten: fmt.integer(kcal), goal: goalKcal != null ? fmt.integer(goalKcal) : "—" });

  return (
    <Card variant="hero" className="flex flex-col gap-6 xl:flex-row xl:items-center xl:gap-8" style={{ padding: 28 }} data-testid="calorie-hero">
      <div className="flex items-center justify-center gap-5 sm:justify-start sm:gap-8 xl:shrink-0">
        <ProgressRing progress={state.ringProgress} color="var(--metric-kcal)" size={ringSize} aria-label={ringLabel}>
          <div className="flex flex-col items-center leading-none">
            <span data-testid="hero-number" style={{ fontSize: numberSize, fontWeight: 800, letterSpacing: "-0.03em" }}>
              <AnimatedNumber value={state.number} format={(n) => fmt.integer(n)} />
            </span>
            <span
              data-testid="hero-caption"
              className="mt-1.5 type-body-s"
              style={{ color: over ? "var(--m-kcal)" : "var(--text-2)", fontWeight: 600, maxWidth: ringSize - 44, textAlign: "center" }}
            >
              {t(state.captionKey)}
            </span>
            {/* The phone layout has no eaten/goal column beside the ring — it sits under the caption instead. */}
            {goalKcal != null && goalKcal > 0 && (
              <span className="tabular mt-1 sm:hidden" style={{ fontSize: 12, fontWeight: 600, color: "var(--text-3)" }} data-testid="hero-ring-sub">
                {fmt.integer(kcal)} / {fmt.integer(goalKcal)}
              </span>
            )}
          </div>
        </ProgressRing>

        <div className="hidden min-w-0 flex-col gap-3 sm:flex">
          <div>
            <p className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>
              {t("eatenLabel")}
            </p>
            <MetricValue value={fmt.integer(kcal)} unit="kcal" size={22} unitRatio={0.6} />
          </div>
          {state.showGoalLine && goalKcal != null && (
            <div>
              <p className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>
                {t("dailyGoalLabel")}
              </p>
              <MetricValue value={fmt.integer(goalKcal)} unit="kcal" size={22} unitRatio={0.6} />
            </div>
          )}
        </div>
      </div>

      <div className="flex flex-col gap-5 min-w-0 xl:flex-1">
        <div className="grid gap-3 sm:grid-cols-3 sm:gap-5 xl:grid-cols-1 xl:gap-3.5">
          {MACROS.map(({ key, color }) => {
            const { value, goal } = macros[key];
            const row = macroRowState(value, goal);
            const valueText = row.hasGoal
              ? `${fmt.integer(value)} / ${fmt.integer(goal!)} g · ${row.over > 0 ? t("macroOver", { n: fmt.integer(row.over) }) : t("macroLeft", { n: fmt.integer(row.left) })}`
              : `${fmt.integer(value)} g`;
            return (
              <div
                key={key}
                data-testid={`macro-${key}`}
                className="grid grid-cols-[72px_minmax(0,1fr)] items-center gap-x-3 gap-y-1.5 sm:grid-cols-1 xl:grid-cols-[minmax(0,1fr)_auto] xl:gap-x-4 2xl:grid-cols-[88px_minmax(0,1fr)_auto]"
              >
                <span className="order-1" style={{ fontSize: 14, fontWeight: 600, color: "var(--text-2)" }}>{t(key)}</span>
                {row.hasGoal ? (
                  <div className="order-2 xl:order-3 xl:col-span-2 2xl:order-2 2xl:col-span-1">
                    <MetricBar progress={row.progress} color={color} />
                  </div>
                ) : null}
                <span
                  className="tabular order-3 col-span-2 sm:col-span-1 xl:order-2 xl:col-span-1 xl:text-right 2xl:order-3"
                  style={{ fontSize: 13, fontWeight: 600, color: "var(--text-3)" }}
                >
                  {valueText}
                </span>
              </div>
            );
          })}
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <Button onClick={onAdd} className="flex-1 sm:flex-none">
            <Icon name="add" size={20} />
            <span className="sm:hidden">{t("addMealShort")}</span>
            <span className="hidden sm:inline">{t("addMeal")}</span>
          </Button>
          {secondaryAction}
        </div>

        {showGoalsHint && (
          <Link href="/settings" className="type-body-s hover:underline" style={{ color: "var(--primary)", fontWeight: 700 }}>
            {t("setGoalsHint")}
          </Link>
        )}
      </div>
    </Card>
  );
}

/** The dashboard's connected hero: today's totals and goals in, the add-meal
 *  dialog (and the `N` shortcut) out. */
export function CalorieHero({ data, secondaryAction }: { data: DashboardData; secondaryAction?: ReactNode }) {
  const t = useTranslations("dashboard");
  const { settings, totals, date } = data;
  const [adding, setAdding] = useState(false);

  const openAdd = useCallback(() => setAdding(true), []);
  usePageShortcuts({ onNew: openAdd, newLabel: t("addMeal") });

  return (
    <>
      <CalorieHeroView
        kcal={totals.kcal}
        goalKcal={settings?.dailyCalorieGoal ?? null}
        macros={{
          protein: { value: totals.protein, goal: settings?.dailyProteinGoal ?? null },
          carbs: { value: totals.carbs, goal: settings?.dailyCarbsGoal ?? null },
          fat: { value: totals.fat, goal: settings?.dailyFatGoal ?? null },
        }}
        onAdd={openAdd}
        secondaryAction={secondaryAction ?? <CopyYesterdayButton meals={data.meals} isToday={isSameDay(date, new Date())} />}
        showGoalsHint={!settings?.dailyCalorieGoal && !settings?.dailyProteinGoal}
      />
      {adding && <AddFoodFlow date={date} onClose={() => setAdding(false)} />}
    </>
  );
}
