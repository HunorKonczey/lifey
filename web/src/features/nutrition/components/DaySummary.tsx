"use client";

import { useTranslations } from "next-intl";
import { AnimatedNumber, Card, MetricBar, MetricValue, ProgressRing } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { heroState, macroRowState } from "@/features/dashboard/calorieHero";

const MACROS = [
  { key: "protein", color: "var(--metric-protein)" },
  { key: "carbs", color: "var(--metric-carbs)" },
  { key: "fat", color: "var(--metric-fat)" },
] as const;

export type SummaryMacroKey = (typeof MACROS)[number]["key"];

export interface DaySummaryViewProps {
  kcal: number;
  goalKcal: number | null;
  macros: Record<SummaryMacroKey, { value: number; goal: number | null }>;
}

/**
 * The meals tab's "Daily summary" (W2.2, client-004): the day's budget as the
 * hero of the right-hand panel — a ring with what's left in kcal, eaten and
 * goal beside it, and three macro bars with "68 / 120 g" (no fibre or sugar).
 * The three states (remaining / over / no goal) are the dashboard hero's own
 * (`heroState`), so the two screens never disagree about what is left.
 */
export function DaySummaryView({ kcal, goalKcal, macros }: DaySummaryViewProps) {
  const t = useTranslations("dashboard");
  const n = useTranslations("nutrition");
  const fmt = useFormat();
  const state = heroState(kcal, goalKcal);

  return (
    <Card variant="hero" className="flex flex-col gap-5" style={{ padding: 22 }} data-testid="day-summary">
      <span className="type-section" style={{ color: "var(--text-3)" }}>
        {n("dailySummary")}
      </span>

      <div className="flex items-center gap-5">
        <ProgressRing
          progress={state.ringProgress}
          color="var(--metric-kcal)"
          size={112}
          aria-label={t("heroRingLabel", { eaten: fmt.integer(kcal), goal: goalKcal != null ? fmt.integer(goalKcal) : "—" })}
        >
          <div className="flex flex-col items-center leading-none">
            <span data-testid="summary-number" style={{ fontSize: 30, fontWeight: 800, letterSpacing: "-0.03em" }}>
              <AnimatedNumber value={state.number} format={(v) => fmt.integer(v)} />
            </span>
            <span
              data-testid="summary-caption"
              className="mt-1 type-label"
              style={{ color: state.mode === "over" ? "var(--m-kcal)" : "var(--text-2)", maxWidth: 76, textAlign: "center" }}
            >
              {t(state.captionKey)}
            </span>
          </div>
        </ProgressRing>

        <div className="flex min-w-0 flex-col gap-2.5">
          <div>
            <p className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>
              {t("eatenLabel")}
            </p>
            <MetricValue value={fmt.integer(kcal)} unit="kcal" size={18} unitRatio={0.7} />
          </div>
          {state.showGoalLine && goalKcal != null && (
            <div>
              <p className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>
                {n("goalLabel")}
              </p>
              <MetricValue value={fmt.integer(goalKcal)} unit="kcal" size={18} unitRatio={0.7} />
            </div>
          )}
        </div>
      </div>

      <div className="flex flex-col gap-3.5">
        {MACROS.map(({ key, color }) => {
          const { value, goal } = macros[key];
          const row = macroRowState(value, goal);
          return (
            <div key={key} className="flex flex-col gap-1.5" data-testid={`summary-${key}`}>
              <div className="flex items-baseline justify-between gap-3">
                <span style={{ fontSize: 14, fontWeight: 600, color: "var(--text-2)" }}>{t(key)}</span>
                <span className="tabular" style={{ fontSize: 13, fontWeight: 600, color: row.over > 0 ? "var(--m-kcal)" : "var(--text)" }}>
                  {row.hasGoal ? `${fmt.integer(value)} / ${fmt.integer(goal!)} g` : `${fmt.integer(value)} g`}
                </span>
              </div>
              {row.hasGoal && <MetricBar progress={row.progress} color={color} />}
            </div>
          );
        })}
      </div>
    </Card>
  );
}
