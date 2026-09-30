"use client";

import { Suspense, useCallback, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQueries, useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { endOfDay } from "date-fns";
import { queryKeys } from "@/lib/api/queryKeys";
import { mealApi } from "@/features/nutrition/api";
import { weightApi } from "@/features/weight/api";
import { waterApi } from "@/features/water/api";
import { stepsApi } from "@/features/steps/api";
import { workoutSessionApi } from "@/features/workouts/api";
import { aggregate, type RawData, type StatKindFilter } from "@/features/statistics/aggregate";
import { Button, Icon, SectionLabel } from "@/components/ds";
import { CaloriesChartCard } from "@/features/statistics/components/CaloriesChartCard";
import { WeightChartCard } from "@/features/statistics/components/WeightChartCard";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { KpiRow } from "@/features/statistics/components/KpiRow";
import { buildPeriodStats } from "@/features/statistics/periodStats";
import { settingsApi } from "@/features/settings/api";
import { userDetailsApi } from "@/features/onboarding/api";
import { effectiveDailyStepGoal } from "@/features/steps/walking";
import { PeriodControl } from "@/features/statistics/components/PeriodControl";
import { parsePeriodState, periodRange, periodSearch, previousPeriod, type PeriodState } from "@/features/statistics/period";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useTopBarCentre, useTopBarTrailing } from "@/lib/hooks/useTopBarSlot";
import { TimeSeriesChart } from "@/components/data/TimeSeriesChartLazy";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { EmptyState } from "@/components/status/EmptyState";
import type { MealResponse } from "@/features/nutrition/types";
import type { WeightResponse } from "@/features/weight/types";
import type { WaterEntryResponse } from "@/features/water/types";
import type { DailyStepCountResponse } from "@/features/steps/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";
import { DATE_LOCALES, useFormat } from "@/lib/i18n/format";

function ChartCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
      <p className="text-sm font-bold mb-4">{title}</p>
      {children}
    </div>
  );
}

/** The period lives in the URL (`?period=week&start=2026-09-21`) so a view can be linked and survives a reload. */
export default function StatisticsPage() {
  return (
    <Suspense fallback={null}>
      <Statistics />
    </Suspense>
  );
}

function Statistics() {
  const t = useTranslations("statistics");
  const fmt = useFormat();
  const locale = fmt.locale;
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const phone = useMediaQuery("(max-width: 767px)");
  const [kindFilter, setKindFilter] = useState<StatKindFilter>("ALL");

  const state = useMemo(() => parsePeriodState(new URLSearchParams(searchParams.toString()), new Date()), [searchParams]);
  const setState = useCallback(
    (next: PeriodState) => router.replace(`${pathname}?${periodSearch(next)}`, { scroll: false }),
    [router, pathname],
  );
  const { period } = state;

  // Fajta-szűrő (docs/cardio/56 D-C3.4) — re-scopes workoutCount/trainingVolume,
  // not the nutrition/weight/water/steps charts, which aren't "edzés jellegű".
  const KIND_OPTIONS: { value: StatKindFilter; label: string }[] = [
    { value: "ALL", label: t("kindAll") },
    { value: "STRENGTH", label: t("kindStrength") },
    { value: "CARDIO", label: t("kindCardio") },
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
  // Goals come from settings and onboarding; neither is required (404 = onboarding not done — no goal weight).
  const settingsQ = useQuery({ queryKey: queryKeys.settings.all(), queryFn: settingsApi.get, staleTime: 5 * 60_000 });
  const userDetailsQ = useQuery({ queryKey: queryKeys.userDetails.all(), queryFn: userDetailsApi.get, retry: false });
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
    const label = period === "week" ? "EEE" : locale === "hu" ? "MMM d." : "MMM d";
    const dateLocale = DATE_LOCALES[locale];
    const cur = periodRange(period, state.start);
    const prev = previousPeriod(period, state.start);
    return {
      current: aggregate(raw, cur.start, endOfDay(cur.end), label, kindFilter, dateLocale),
      previous: aggregate(raw, prev.start, endOfDay(prev.end), label, kindFilter, dateLocale),
    };
  }, [raw, period, state.start, kindFilter, locale]);

  const calorieGoal = settingsQ.data?.dailyCalorieGoal ?? null;
  const stepGoal = effectiveDailyStepGoal(settingsQ.data);
  const weightGoal = userDetailsQ.data?.targetWeightKg ?? null;
  const stats = useMemo(
    () => buildPeriodStats({ raw, period, start: state.start, now: new Date(), goals: { calories: calorieGoal, steps: stepGoal, weightKg: weightGoal } }),
    [raw, period, state.start, calorieGoal, stepGoal, weightGoal],
  );

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
    a.download = `lifey-stats-${period}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // The period control sits in the top bar's centre and the export beside the theme toggle; a phone has no top bar
  // (W5-D), so both move into the page header below.
  const periodControl = useMemo(() => <PeriodControl state={state} onChange={setState} />, [state, setState]);
  useTopBarCentre(phone ? null : periodControl);
  const exportButton = useMemo(
    () => (
      <Button variant="secondary" onClick={exportCsv}>
        <Icon name="download" size={20} />
        {t("export")}
      </Button>
    ),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- exportCsv closes over the current series
    [current, t],
  );
  useTopBarTrailing(phone ? null : exportButton);

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

  return (
    <div className="flex flex-col gap-5">
      {phone && (
        <div className="flex flex-col gap-3">
          <div className="flex justify-end">{exportButton}</div>
          <PeriodControl state={state} onChange={setState} stacked />
        </div>
      )}
      <div className="flex items-center gap-3 flex-wrap">
        <SegmentedControl options={KIND_OPTIONS} value={kindFilter} onChange={setKindFilter} size="sm" />
      </div>

      <KpiRow stats={stats} />

      <SectionLabel>{t("sectionNutrition")}</SectionLabel>
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4 md:gap-6">
        <CaloriesChartCard stats={stats} compact={phone} />
        <WeightChartCard stats={stats} compact={phone} />
      </div>

      {/* Chart grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title={t("trainingVolume")}>
          {current.totalVolume > 0 ? (
            <TimeSeriesChart data={current.volumeSeries} color="var(--metric-protein)" unit=" kg" />
          ) : (
            <p className="text-sm text-center py-16" style={{ color: "var(--muted)" }}>{t("noSetsLogged")}</p>
          )}
        </ChartCard>

        <ChartCard title={t("cardioDistance")}>
          {current.cardioDistanceSeries.length > 0 ? (
            <TimeSeriesChart data={current.cardioDistanceSeries} color="var(--tertiary)" unit=" km" />
          ) : (
            <p className="text-sm text-center py-16" style={{ color: "var(--muted)" }}>{t("noCardioDistance")}</p>
          )}
        </ChartCard>

        <ChartCard title={t("steps")}>
          <TimeSeriesChart data={current.stepsSeries} color="var(--metric-steps)" />
        </ChartCard>
      </div>
    </div>
  );
}
