"use client";

import { useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { LifeyBarChart, type BarChartDatum } from "@/components/ds/charts/LifeyBarChart.lazy";
import { useFormat } from "@/lib/format/useFormat";
import type { WaterWindow } from "../waterStats";

/**
 * "Az elmúlt 14 nap" (W4.5, W4-B): the average and "cél teljesítve 6 / 13 nap" (today left out), and 14 bars — days
 * that reached the goal in full colour, the others at 45 %, a dashed goal line, today a dashed outline.
 */
export function WaterTrendCard({ window: w, goal }: { window: WaterWindow; goal: number }) {
  const t = useTranslations("water");
  const fmt = useFormat();

  const data: BarChartDatum[] = w.days.map((d) => ({
    label: d.isToday ? t("todayShort") : String(d.date.getDate()),
    value: d.liters > 0 ? d.liters : null,
    isToday: d.isToday,
    dimmed: !d.met,
    semanticsLabel: `${fmt.shortDate(d.date)}, ${fmt.litres(d.liters)}`,
  }));

  return (
    <Card data-testid="water-trend">
      <div className="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-1">
        <h2 className="type-title-s">{t("trendTitle")}</h2>
        <p className="type-body-s tabular" style={{ color: "var(--text-2)" }} data-testid="water-trend-stats">
          {[w.average != null ? t("trendAverage", { litres: fmt.litres(Math.round(w.average * 10) / 10) }) : null, t("trendMet", { met: w.metDays, total: w.completeDays })]
            .filter(Boolean)
            .join(" · ")}
        </p>
      </div>
      <div className="mt-3">
        <LifeyBarChart
          aria-label={t("trendAria")}
          data={data}
          color="var(--m-water)"
          goal={goal}
          goalLabel={t("trendGoalLabel", { litres: fmt.litres(goal) })}
          // Whole litres on top: 0 / 2,5 / 5 beats the default "0,0 / 2,05 / 4,1".
          yMax={Math.max(1, Math.ceil(Math.max(goal, ...w.days.map((d) => d.liters))))}
          yFormat={(v) => (Number.isInteger(v) ? fmt.integer(v) : fmt.litreNumber(v))}
          height={220}
        />
      </div>
    </Card>
  );
}
