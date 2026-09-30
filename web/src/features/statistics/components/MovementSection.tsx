"use client";

import { useTranslations } from "next-intl";
import { SegmentedControl } from "@/components/ds";
import type { PeriodStats } from "../periodStats";
import { STAT_KIND_FILTERS, type StatKindFilter } from "../types";
import { CardioDistanceCard, StepsChartCard, VolumeChartCard } from "./MovementCards";

/**
 * "MOZGÁS" (W5.5, W5-A): the three movement charts under a header that carries the **Mind · Erősítő · Cardio**
 * filter, so it is plain that it filters *these* and not the calories and weight above. Mind shows volume, cardio
 * distance and steps; Erősítő drops the cardio card, Cardio drops the volume card — steps are not a workout kind and
 * stay. The filter changes which cards are drawn, never a number on any of them.
 */
export function MovementSection({
  stats,
  filter,
  onFilterChange,
  compact,
}: {
  stats: PeriodStats;
  filter: StatKindFilter;
  onFilterChange: (next: StatKindFilter) => void;
  compact?: boolean;
}) {
  const t = useTranslations("statistics");
  const showVolume = filter !== "CARDIO";
  const showCardio = filter !== "STRENGTH";
  const columns = showVolume && showCardio ? "xl:grid-cols-3" : "xl:grid-cols-2";

  return (
    <section className="flex flex-col gap-4" aria-labelledby="stats-movement-heading" data-testid="stats-movement">
      <div className="flex items-center gap-3">
        <h2 id="stats-movement-heading" className="type-section" style={{ color: "var(--text-3)" }}>
          {t("sectionMovement")}
        </h2>
        <div className="flex-1 h-px" style={{ background: "var(--hairline)" }} aria-hidden />
        <SegmentedControl<StatKindFilter>
          aria-label={t("kindAria")}
          size="sm"
          options={STAT_KIND_FILTERS.map((k) => ({ value: k, label: t(`kind_${k}`) }))}
          value={filter}
          onChange={onFilterChange}
        />
      </div>
      <div className={`grid grid-cols-1 md:grid-cols-2 ${columns} gap-4 md:gap-6`}>
        {showVolume && <VolumeChartCard stats={stats} compact={compact} />}
        {showCardio && <CardioDistanceCard stats={stats} compact={compact} />}
        <StepsChartCard stats={stats} compact={compact} />
      </div>
    </section>
  );
}
