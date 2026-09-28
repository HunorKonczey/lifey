"use client";

import { LifeyLineChart } from "@/components/ds/charts/LifeyLineChart";

export interface SeriesPoint {
  date: string; // pre-formatted label
  value: number;
}

interface TimeSeriesChartProps {
  data: SeriesPoint[];
  color: string;
  goalLine?: number;
  goalLabel?: string;
  height?: number;
  unit?: string;
}

/**
 * A thin adapter over `LifeyLineChart` (D-W0.9/W0.19) — kept so the
 * weight/statistics/trainer call sites that already pass a pre-formatted
 * `SeriesPoint[]` (a display string, not a real per-point `Date`) keep
 * working unchanged. Deleted in W10.3 once those call sites move onto
 * `LifeyLineChart` directly with real dates (gaining gaps/average/goal-ring
 * along the way). Synthetic sequential dates only drive `LifeyLineChart`'s
 * internal bookkeeping (last-point lookup) — every point's `label` override
 * keeps the caller's own original date string on the X axis.
 */
export function TimeSeriesChart({ data, color, goalLine, goalLabel, height = 240, unit = "" }: TimeSeriesChartProps) {
  const epoch = new Date(2000, 0, 1).getTime();
  const dayMs = 86_400_000;

  return (
    <LifeyLineChart
      data={data.map((p, i) => ({
        date: new Date(epoch + i * dayMs),
        value: p.value,
        label: p.date,
      }))}
      color={color}
      goal={goalLine}
      goalLabel={goalLabel}
      unit={unit}
      height={height}
    />
  );
}
