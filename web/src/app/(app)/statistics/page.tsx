"use client";

import { useState, useMemo } from "react";
import { useQueries } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { subDays, startOfDay, endOfDay } from "date-fns";
import { queryKeys } from "@/lib/api/queryKeys";
import { mealApi } from "@/features/nutrition/api";
import { weightApi } from "@/features/weight/api";
import { waterApi } from "@/features/water/api";
import { stepsApi } from "@/features/steps/api";
import { workoutSessionApi } from "@/features/workouts/api";
import { aggregate, type RawData } from "@/features/statistics/aggregate";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { KpiCard } from "@/components/data/KpiCard";
import { TimeSeriesChart } from "@/components/data/TimeSeriesChartLazy";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { EmptyState } from "@/components/status/EmptyState";
import type { MealResponse } from "@/features/nutrition/types";
import type { WeightResponse } from "@/features/weight/types";
import type { WaterEntryResponse } from "@/features/water/types";
import type { DailyStepCountResponse } from "@/features/steps/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

type Range = "WEEK" | "MONTH" | "YEAR";

const RANGE_DAYS: Record<Range, number> = { WEEK: 7, MONTH: 30, YEAR: 365 };

function ChartCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
      <p className="text-sm font-bold mb-4">{title}</p>
      {children}
    </div>
  );
}

export default function StatisticsPage() {
  const t = useTranslations("statistics");
  const [range, setRange] = useState<Range>("WEEK");

  const RANGE_OPTIONS: { value: Range; label: string }[] = [
    { value: "WEEK", label: t("week") },
    { value: "MONTH", label: t("month") },
    { value: "YEAR", label: t("year") },
  ];

  const results = useQueries({
    queries: [
      { queryKey: queryKeys.meals.all(), queryFn: mealApi.list },
      { queryKey: queryKeys.weights.all(), queryFn: weightApi.list },
      { queryKey: queryKeys.waterEntries.all(), queryFn: waterApi.entries.list },
      { queryKey: queryKeys.steps.all(), queryFn: stepsApi.list },
      { queryKey: queryKeys.workoutSessions.all(), queryFn: workoutSessionApi.list },
    ],
  });

  const [mealsQ, weightsQ, waterQ, stepsQ, sessionsQ] = results;
  const isLoading = results.some((r) => r.isLoading);
  const isError = results.some((r) => r.isError);

  const raw: RawData = useMemo(() => ({
    meals: (mealsQ.data as MealResponse[]) ?? [],
    weights: (weightsQ.data as WeightResponse[]) ?? [],
    water: (waterQ.data as WaterEntryResponse[]) ?? [],
    steps: (stepsQ.data as DailyStepCountResponse[]) ?? [],
    sessions: (sessionsQ.data as WorkoutSessionResponse[]) ?? [],
  }), [mealsQ.data, weightsQ.data, waterQ.data, stepsQ.data, sessionsQ.data]);

  const { current, previous } = useMemo(() => {
    const days = RANGE_DAYS[range];
    const label = range === "WEEK" ? "EEE" : "MMM d";
    const now = new Date();
    const curStart = startOfDay(subDays(now, days - 1));
    const curEnd = endOfDay(now);
    const prevStart = startOfDay(subDays(now, days * 2 - 1));
    const prevEnd = endOfDay(subDays(now, days));
    return {
      current: aggregate(raw, curStart, curEnd, label),
      previous: aggregate(raw, prevStart, prevEnd, label),
    };
  }, [raw, range]);

  const exportCsv = () => {
    const rows = [["date", "calories", "protein", "water_l", "steps", "volume"]];
    current.caloriesSeries.forEach((p, i) => {
      rows.push([
        p.date,
        String(p.value),
        String(current.proteinSeries[i]?.value ?? 0),
        String(current.waterSeries[i]?.value ?? 0),
        String(current.stepsSeries[i]?.value ?? 0),
        String(current.volumeSeries[i]?.value ?? 0),
      ]);
    });
    const csv = rows.map((r) => r.join(",")).join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `lifey-stats-${range.toLowerCase()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  if (isLoading) {
    return (
      <div className="flex flex-col gap-5">
        <Skeleton variant="card" className="h-10 w-64" />
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {[0, 1, 2, 3].map((i) => <Skeleton key={i} variant="card" className="h-24" />)}
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {[0, 1, 2, 3].map((i) => <Skeleton key={i} variant="chart" />)}
        </div>
      </div>
    );
  }

  if (isError) return <ErrorState onRetry={() => results.forEach((r) => r.refetch())} />;

  const hasAnyData =
    raw.meals.length || raw.weights.length || raw.water.length || raw.steps.length || raw.sessions.length;

  if (!hasAnyData) {
    return <EmptyState icon="bar_chart" title={t("noDataYet")}
      body={t("logToSeeStats")} />;
  }

  const weightDeltaPrev =
    current.weightChange != null && previous.weightChange != null
      ? Number((current.weightChange - previous.weightChange).toFixed(1))
      : null;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <SegmentedControl options={RANGE_OPTIONS} value={range} onChange={setRange} />
        <button onClick={exportCsv}
          className="flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
          style={{ background: "var(--surface)", border: "1px solid var(--outline)", color: "var(--on-surface-variant)" }}>
          <span className="material-symbols-rounded text-lg">ios_share</span> {t("export")}
        </button>
      </div>

      {/* KPI row */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label={t("avgCalories")} value={current.avgCalories.toLocaleString()} icon="local_fire_department"
          color="var(--metric-kcal)" delta={current.avgCalories - previous.avgCalories} higherIsBetter={false} />
        <KpiCard label={t("workouts")} value={String(current.workoutCount)} icon="exercise"
          color="var(--tertiary)" delta={current.workoutCount - previous.workoutCount} higherIsBetter />
        <KpiCard label={t("weight")} value={current.latestWeight != null ? `${current.latestWeight.toFixed(1)} kg` : "—"}
          icon="monitor_weight" color="var(--metric-weight)" delta={weightDeltaPrev} higherIsBetter={false} deltaUnit=" kg" />
        <KpiCard label={t("trainingVolume")} value={`${Math.round(current.totalVolume).toLocaleString()} kg`} icon="fitness_center"
          color="var(--metric-protein)" delta={Math.round(current.totalVolume - previous.totalVolume)} higherIsBetter deltaUnit=" kg" />
      </div>

      {/* Chart grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title={t("calories")}>
          <TimeSeriesChart data={current.caloriesSeries} color="var(--metric-kcal)" unit=" kcal" />
        </ChartCard>

        <ChartCard title={t("weight")}>
          {current.weightSeries.length > 0 ? (
            <TimeSeriesChart data={current.weightSeries} color="var(--metric-weight)" unit=" kg" />
          ) : (
            <p className="text-sm text-center py-16" style={{ color: "var(--muted)" }}>{t("noWeightEntries")}</p>
          )}
        </ChartCard>

        <ChartCard title={t("trainingVolume")}>
          {current.totalVolume > 0 ? (
            <TimeSeriesChart data={current.volumeSeries} color="var(--metric-protein)" unit=" kg" />
          ) : (
            <p className="text-sm text-center py-16" style={{ color: "var(--muted)" }}>{t("noSetsLogged")}</p>
          )}
        </ChartCard>

        <ChartCard title={t("steps")}>
          <TimeSeriesChart data={current.stepsSeries} color="var(--metric-steps)" />
        </ChartCard>
      </div>
    </div>
  );
}
