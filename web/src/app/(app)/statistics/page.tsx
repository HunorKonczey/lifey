"use client";

import { Suspense, useCallback, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQueries, useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { SectionLabel } from "@/components/ds";
import { ExportControl } from "@/features/statistics/components/ExportPopover";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { mealApi } from "@/features/nutrition/api";
import { userDetailsApi } from "@/features/onboarding/api";
import { settingsApi } from "@/features/settings/api";
import { stepsApi } from "@/features/steps/api";
import { effectiveDailyStepGoal } from "@/features/steps/walking";
import { CaloriesChartCard } from "@/features/statistics/components/CaloriesChartCard";
import { KpiRow } from "@/features/statistics/components/KpiRow";
import { MovementSection } from "@/features/statistics/components/MovementSection";
import { PeriodControl, usePeriodLabel } from "@/features/statistics/components/PeriodControl";
import { WeightChartCard } from "@/features/statistics/components/WeightChartCard";
import { parsePeriodState, periodSearch, type PeriodState } from "@/features/statistics/period";
import { buildPeriodStats } from "@/features/statistics/periodStats";
import type { RawData, StatKindFilter } from "@/features/statistics/types";
import { waterApi } from "@/features/water/api";
import { weightApi } from "@/features/weight/api";
import { workoutSessionApi } from "@/features/workouts/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useTopBarCentre, useTopBarTrailing } from "@/lib/hooks/useTopBarSlot";

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
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const phone = useMediaQuery("(max-width: 767px)");
  // The Strength / Cardio filter belongs to the Mozgás section only (W5.5) — it never touches the rest of the page.
  const [kindFilter, setKindFilter] = useState<StatKindFilter>("ALL");

  const state = useMemo(() => parsePeriodState(new URLSearchParams(searchParams.toString()), new Date()), [searchParams]);
  const setState = useCallback(
    (next: PeriodState) => router.replace(`${pathname}?${periodSearch(next)}`, { scroll: false }),
    [router, pathname],
  );
  const { period } = state;

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

  const raw: RawData = useMemo(
    () => ({
      meals: mealsQ.data ?? [],
      weights: weightsQ.data ?? [],
      water: waterQ.data ?? [],
      steps: stepsQ.data ?? [],
      sessions: sessionsQ.data ?? [],
    }),
    [mealsQ.data, weightsQ.data, waterQ.data, stepsQ.data, sessionsQ.data],
  );

  const calorieGoal = settingsQ.data?.dailyCalorieGoal ?? null;
  const stepGoal = effectiveDailyStepGoal(settingsQ.data);
  const weightGoal = userDetailsQ.data?.targetWeightKg ?? null;
  const stats = useMemo(
    () => buildPeriodStats({ raw, period, start: state.start, now: new Date(), goals: { calories: calorieGoal, steps: stepGoal, weightKg: weightGoal } }),
    [raw, period, state.start, calorieGoal, stepGoal, weightGoal],
  );

  // The period control sits in the top bar's centre and the export beside the theme toggle; a phone has no top bar
  // (W5-D), so both move into the page header below.
  const periodControl = useMemo(() => <PeriodControl state={state} onChange={setState} />, [state, setState]);
  useTopBarCentre(phone ? null : periodControl);
  const periodLabel = usePeriodLabel()(state);
  const exportControl = useMemo(
    () => (
      <ExportControl raw={raw} viewed={stats.range} period={period} isCurrent={stats.isCurrent} periodLabel={periodLabel} iconOnly={phone} />
    ),
    [raw, stats.range, stats.isCurrent, period, periodLabel, phone],
  );
  useTopBarTrailing(phone ? null : exportControl);

  if (isLoading) {
    return (
      <div className="flex flex-col gap-5">
        <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">
          {[0, 1, 2, 3, 4, 5].map((i) => <Skeleton key={i} variant="card" className="h-28" />)}
        </div>
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          {[0, 1].map((i) => <Skeleton key={i} variant="chart" />)}
        </div>
      </div>
    );
  }

  if (isError) return <ErrorState onRetry={() => results.forEach((r) => r.refetch())} />;

  const hasAnyData = raw.meals.length || raw.weights.length || raw.water.length || raw.steps.length || raw.sessions.length;
  if (!hasAnyData) return <EmptyState icon="bar_chart" title={t("noDataYet")} body={t("logToSeeStats")} />;

  return (
    <div className="flex flex-col gap-5">
      {phone && (
        <PeriodControl state={state} onChange={setState} stacked endSlot={exportControl} />
      )}

      <KpiRow stats={stats} />

      <SectionLabel>{t("sectionNutrition")}</SectionLabel>
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4 md:gap-6">
        <CaloriesChartCard stats={stats} compact={phone} />
        <WeightChartCard stats={stats} compact={phone} />
      </div>

      <MovementSection stats={stats} filter={kindFilter} onFilterChange={setKindFilter} compact={phone} />
    </div>
  );
}
