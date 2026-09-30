"use client";

import { useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { LifeyBarChart, type BarChartDatum } from "@/components/ds/charts/LifeyBarChart.lazy";
import { useFormat } from "@/lib/format/useFormat";
import type { StepsWindow } from "../stats";

/**
 * "Az elmúlt 14 nap" (W4.6, W4-C, client-024): every bar is steps purple — reaching the goal is a ✓ glyph above the bar
 * and the dashed goal line, never a second colour — with today a dashed outline, the weekday letters in the language
 * ("H K Sze Cs P Szo V"), Y "14 e / 7 e / 0". The ✓ is drawn only over *complete* days that met the goal: today is
 * still accumulating, so it never claims one.
 */
export function StepsTrendCard({ window: w, goal }: { window: StepsWindow; goal: number }) {
  const t = useTranslations("steps");
  const fmt = useFormat();

  const data: BarChartDatum[] = w.days.map((d) => ({
    label: d.isToday ? t("todayShort") : fmt.weekdayShort(d.date),
    value: d.steps > 0 ? d.steps : null,
    isToday: d.isToday,
    metGoal: d.met && !d.isToday,
    semanticsLabel: `${fmt.shortDate(d.date)}, ${fmt.integer(d.steps)}${d.met && !d.isToday ? `, ${t("goalMetAria")}` : ""}`,
  }));

  return (
    <Card data-testid="steps-trend">
      <h2 className="type-title-s">{t("trendTitle")}</h2>
      <div className="mt-3">
        <LifeyBarChart
          aria-label={t("trendAria")}
          data={data}
          color="var(--metric-steps)"
          goal={goal}
          goalLabel={fmt.integer(goal)}
          height={240}
          legend={t("trendLegend", { goal: fmt.integer(goal) })}
        />
      </div>
    </Card>
  );
}
