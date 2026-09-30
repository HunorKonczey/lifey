"use client";

import { useTranslations } from "next-intl";
import { LifeyBarChart, type BarChartDatum } from "@/components/ds/charts/LifeyBarChart.lazy";
import { useFormat } from "@/lib/format/useFormat";
import { axisColumns } from "../chartAxis";
import type { PeriodStats } from "../periodStats";
import { ChartCard, ChartLegend, type LegendItem } from "./ChartCard";

interface CardProps {
  stats: PeriodStats;
  compact?: boolean;
}

function useColumns(stats: PeriodStats) {
  const t = useTranslations("statistics");
  const fmt = useFormat();
  return { t, fmt, columns: axisColumns(stats.period, stats.slots, fmt, t("todayShort")) };
}

/**
 * "Edzésvolumen" (W5.5, W5-A): a bar on a workout day, a small dot on the axis for a finished rest day — never a
 * curve that falls to 0 and climbs again. The figure in the header is the period's total kg.
 */
export function VolumeChartCard({ stats, compact = false }: CardProps) {
  const { t, fmt, columns } = useColumns(stats);
  const { volume, slots } = stats;

  const data: BarChartDatum[] = slots.map((slot, i) => ({
    label: columns[i].key,
    axisLabel: columns[i].axisLabel,
    value: volume.rest[i] ? 0 : volume.values[i],
    isRestDay: volume.rest[i],
    isToday: columns[i].isToday && volume.values[i] != null,
    semanticsLabel: volume.rest[i]
      ? `${fmt.shortDate(slot.start)}, ${t("restDay")}`
      : volume.values[i] == null
        ? fmt.shortDate(slot.start)
        : `${fmt.shortDate(slot.start)}, ${fmt.integer(volume.values[i]!, "kg")}`,
  }));

  const legend: LegendItem[] = [
    { kind: "bar", color: "var(--primary)", label: t("legendWorkoutDay") },
    { kind: "dot", color: "var(--text-3)", label: t("legendRestDay") },
  ];

  return (
    <ChartCard
      testId="stats-volume"
      title={t("trainingVolume")}
      note={volume.total > 0 && <span>{fmt.integer(volume.total, "kg")}</span>}
      footnote={volume.total > 0 ? t("volumeFootnote") : undefined}
    >
      {volume.total > 0 ? (
        <>
          <LifeyBarChart aria-label={t("volumeAria")} data={data} color="var(--primary)" height={compact ? 180 : 200} />
          <ChartLegend items={legend} />
        </>
      ) : (
        <p className="type-body-s text-center py-16" style={{ color: "var(--text-3)" }}>
          {t("noSetsLogged")}
        </p>
      )}
    </ChartCard>
  );
}

/**
 * "Cardio táv" (W5.5): a bar per session day with its value over it (14,8 · 5,2) and nothing between — two
 * measurements are not joined by an invented valley.
 */
export function CardioDistanceCard({ stats, compact = false }: CardProps) {
  const { t, fmt, columns } = useColumns(stats);
  const { cardio, slots } = stats;

  const data: BarChartDatum[] = slots.map((slot, i) => ({
    label: columns[i].key,
    axisLabel: columns[i].axisLabel,
    value: cardio.values[i],
    valueLabel: cardio.values[i] == null || stats.period !== "week" ? undefined : fmt.number(cardio.values[i]!),
    isToday: columns[i].isToday && cardio.values[i] != null,
    semanticsLabel: cardio.values[i] == null ? fmt.shortDate(slot.start) : `${fmt.shortDate(slot.start)}, ${fmt.number(cardio.values[i]!)} km`,
  }));

  return (
    <ChartCard
      testId="stats-cardio"
      title={t("cardioDistance")}
      note={cardio.totalKm > 0 && <span>{`${fmt.number(cardio.totalKm)} km · ${t("sessionCount", { count: cardio.sessions })}`}</span>}
      footnote={cardio.totalKm > 0 ? t("cardioFootnote") : undefined}
    >
      {cardio.totalKm > 0 ? (
        <>
          <LifeyBarChart
            aria-label={t("cardioAria")}
            data={data}
            color="var(--heart)"
            yFormat={(v) => fmt.number(v)}
            height={compact ? 180 : 200}
          />
          <ChartLegend items={[{ kind: "bar", color: "var(--heart)", label: t("legendCardioDay") }]} />
        </>
      ) : (
        <p className="type-body-s text-center py-16" style={{ color: "var(--text-3)" }}>
          {t("noCardioDistance")}
        </p>
      )}
    </ChartCard>
  );
}

/** "Lépések" (W5.5): one colour, the dashed goal line, today dashed and out of the average. */
export function StepsChartCard({ stats, compact = false }: CardProps) {
  const { t, fmt, columns } = useColumns(stats);
  const { steps, slots } = stats;

  const data: BarChartDatum[] = slots.map((slot, i) => ({
    label: columns[i].key,
    axisLabel: columns[i].axisLabel,
    value: steps.values[i],
    isToday: columns[i].isToday && steps.values[i] != null,
    semanticsLabel: steps.values[i] == null ? `${fmt.shortDate(slot.start)}, ${t("notLogged")}` : `${fmt.shortDate(slot.start)}, ${fmt.integer(steps.values[i]!)}`,
  }));
  const hasData = steps.values.some((v) => v != null);
  const showToday = stats.period !== "year" && stats.isCurrent && slots.some((s, i) => s.isCurrent && steps.values[i] != null);

  const legend: LegendItem[] = [{ kind: "dashed", color: "var(--m-steps)", label: t("legendGoal", { goal: fmt.integer(steps.goal) }) }];
  if (steps.average != null) legend.push({ kind: "bar", color: "var(--m-steps)", label: t("legendSteps") });
  if (showToday) legend.push({ kind: "outline", color: "var(--m-steps)", label: t("legendToday") });

  return (
    <ChartCard
      testId="stats-steps"
      title={t("steps")}
      note={steps.average != null && <span>{t("averageLabel")} <b style={{ color: "var(--text)" }}>{fmt.integer(steps.average)}</b></span>}
      footnote={hasData ? t("stepsFootnote", { goal: fmt.integer(steps.goal) }) : undefined}
    >
      {hasData ? (
        <>
          <LifeyBarChart
            aria-label={t("stepsAria")}
            data={data}
            color="var(--m-steps)"
            goal={steps.goal}
            height={compact ? 180 : 200}
          />
          <ChartLegend items={legend} />
        </>
      ) : (
        <p className="type-body-s text-center py-16" style={{ color: "var(--text-3)" }}>
          {t("noSteps")}
        </p>
      )}
    </ChartCard>
  );
}
