"use client";

import { useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { LifeyLineChart, type LineChartPoint } from "@/components/ds/charts/LifeyLineChart.lazy";
import { useFormat } from "@/lib/format/useFormat";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { buildWeightSeries, type WeightRange } from "../weightSeries";
import type { WeightResponse } from "../types";

/**
 * The weight chart (W4.2, W4-A, client-018/019): the measurements as faint dots, the **7-day average as the bold
 * line**, a dashed goal line, three X labels ("aug. 29. · szept. 13. · ma"), the newest point emphasised. Days
 * without a weigh-in are gaps, never interpolated. "1 év" (and a long "Mind") is weekly means — one point a week
 * and no second average line. The goal line always sits inside the axis (the chart extends the axis to include it).
 */
export function WeightChart({ weights, range, goalKg, now = new Date() }: { weights: WeightResponse[]; range: WeightRange; goalKg: number | null; now?: Date }) {
  const t = useTranslations("weight");
  const fmt = useFormat();
  const phone = useMediaQuery("(max-width: 767px)");
  const series = buildWeightSeries(weights, range, now);
  const todayKey = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();

  // "ma" for today's point, else the short date — the chart only labels the first, middle and last.
  const points: LineChartPoint[] = series.points.map((p) => ({
    ...p,
    label: !series.weekly && p.date.getTime() === todayKey ? t("chartToday") : fmt.shortDate(p.date),
  }));
  const hasData = points.some((p) => p.value != null);

  return (
    <Card data-testid="weight-chart">
      <h2 className="type-title-s mb-3">{t(`chartTitle_${range}`)}</h2>
      {hasData ? (
        <LifeyLineChart
          aria-label={t("chartAria")}
          data={points}
          color="var(--m-weight)"
          goal={goalKg ?? undefined}
          goalLabel={goalKg != null ? t("chartGoalLabel", { weight: Number.isInteger(goalKg) ? fmt.integer(goalKg, "kg") : fmt.weight(goalKg) }) : undefined}
          unit=" kg"
          showAverage={!series.weekly}
          emphasis="average"
          threeXLabels
          dots={!phone}
          height={phone ? 200 : 280}
          legend={{ raw: phone ? undefined : series.weekly ? t("chartLegendWeekly") : t("chartLegendRaw"), average: t("chartLegendAverage"), goal: t("chartLegendGoal") }}
        />
      ) : (
        <p className="type-body-s py-16 text-center" style={{ color: "var(--text-3)" }}>
          {t("noDataInRange")}
        </p>
      )}
    </Card>
  );
}
