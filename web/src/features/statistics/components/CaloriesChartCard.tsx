"use client";

import { useTranslations } from "next-intl";
import { TintedChip } from "@/components/ds";
import { LifeyBarChart, type BarChartDatum } from "@/components/ds/charts/LifeyBarChart.lazy";
import { useFormat } from "@/lib/format/useFormat";
import { axisColumns } from "../chartAxis";
import type { PeriodStats } from "../periodStats";
import { ChartCard, ChartLegend, type LegendItem } from "./ChartCard";

/**
 * "Kalória" (W5.4, W5-A / W5-B): one bar per day, or per week in the year view, where the bars are weekly means of
 * the logged days. Honest by construction: a day with no meal is an empty column (never a 0 bar), today is a dashed
 * outline that the average leaves out, the goal is a dashed line, the average a dotted one, and the header number
 * is the same average the dotted line is drawn at. The year view marks the months before the first log with a
 * hatched "Még nem naplóztál" band and says "Nincs előző évi adat" instead of comparing with an empty year.
 */
export function CaloriesChartCard({ stats, compact = false }: { stats: PeriodStats; compact?: boolean }) {
  const t = useTranslations("statistics");
  const fmt = useFormat();
  const { period, calories, slots } = stats;
  const year = period === "year";
  const columns = axisColumns(period, slots, fmt, t("todayShort"));

  const data: BarChartDatum[] = slots.map((slot, i) => ({
    label: columns[i].key,
    axisLabel: columns[i].axisLabel,
    value: calories.values[i],
    isToday: columns[i].isToday,
    semanticsLabel:
      calories.values[i] == null
        ? `${fmt.shortDate(slot.start)}, ${t("notLogged")}`
        : `${fmt.shortDate(slot.start)}, ${fmt.integer(calories.values[i]!, "kcal")}`,
  }));

  const hasData = calories.values.some((v) => v != null);
  const currentIndex = slots.findIndex((s) => s.isCurrent);
  const showToday = !year && stats.isCurrent && currentIndex >= 0 && calories.values[currentIndex] != null;

  const legend: LegendItem[] = [];
  if (calories.goal != null) legend.push({ kind: "dashed", color: "var(--m-kcal)", label: t("legendGoal", { goal: fmt.integer(calories.goal) }) });
  if (calories.average != null) legend.push({ kind: "dotted", color: "var(--text)", label: t("legendAverage") });
  if (showToday) legend.push({ kind: "outline", color: "var(--m-kcal)", label: t("legendToday") });

  return (
    <ChartCard
      testId="stats-calories"
      title={year ? t("caloriesYear", { year: stats.range.start.getFullYear() }) : t("calories")}
      subtitle={
        year && calories.firstLog
          ? t("weeklyAverageSince", { date: fmt.shortDate(calories.firstLog) })
          : year
            ? t("weeklyAverage")
            : undefined
      }
      note={
        calories.average != null && (
          <span>
            {t("averageLabel")} <b style={{ color: "var(--text)" }}>{fmt.integer(calories.average)}</b>
            {stats.isCurrent && !year ? ` · ${t("withoutToday")}` : ""}
          </span>
        )
      }
      badge={year && calories.previousEmpty && <TintedChip label={t("noPreviousYear")} color="var(--text-2)" />}
    >
      {hasData ? (
        <>
          <LifeyBarChart
            aria-label={t("caloriesAria")}
            data={data}
            color="var(--m-kcal)"
            goal={calories.goal ?? undefined}
            average={calories.average ?? undefined}
            height={compact ? 180 : 220}
            bandBefore={year && calories.emptySlotsBefore > 0 ? { count: calories.emptySlotsBefore, label: t("notLoggedYet") } : undefined}
            marker={year && stats.isCurrent && currentIndex >= 0 ? { index: currentIndex, label: t("todayMarker") } : undefined}
          />
          <ChartLegend items={legend} />
        </>
      ) : (
        <p className="type-body-s text-center py-16" style={{ color: "var(--text-3)" }}>
          {t("noMeals")}
        </p>
      )}
    </ChartCard>
  );
}
