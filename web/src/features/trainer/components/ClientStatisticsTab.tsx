"use client";

import { useMemo, useState } from "react";
import { useQueries, useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { SectionLabel } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { CaloriesChartCard } from "@/features/statistics/components/CaloriesChartCard";
import { KpiRow } from "@/features/statistics/components/KpiRow";
import { MovementSection } from "@/features/statistics/components/MovementSection";
import { PeriodControl } from "@/features/statistics/components/PeriodControl";
import { WeightChartCard } from "@/features/statistics/components/WeightChartCard";
import { parsePeriodState, type PeriodState } from "@/features/statistics/period";
import { buildPeriodStats } from "@/features/statistics/periodStats";
import type { RawData, StatKindFilter } from "@/features/statistics/types";
import { queryKeys } from "@/lib/api/queryKeys";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { trainerApi } from "../api";

interface ClientStatisticsTabProps {
  clientId: number;
}

/**
 * The client's statistics (W7-C): the same W5 cards the client sees — KPI row, calories, weight, movement — fed by the
 * trainer endpoints, scoped to this client and to a period of the trainer's choosing (kept in the tab, not the URL:
 * the top bar belongs to the date stepper here). What the trainer cannot read is simply absent: there is no water
 * history, no step goal and no goal weight, so those lines and bars are not drawn rather than guessed.
 */
export function ClientStatisticsTab({ clientId }: ClientStatisticsTabProps) {
  const t = useTranslations("statistics");
  const phone = useMediaQuery("(max-width: 767px)");
  const [state, setState] = useState<PeriodState>(() => parsePeriodState(new URLSearchParams(), new Date()));
  const [kindFilter, setKindFilter] = useState<StatKindFilter>("ALL");

  const results = useQueries({
    queries: [
      { queryKey: queryKeys.trainerClientData.meals(clientId, "all"), queryFn: () => trainerApi.clientMeals(clientId) },
      { queryKey: queryKeys.trainerClientData.weights(clientId), queryFn: () => trainerApi.clientWeights(clientId) },
      { queryKey: queryKeys.trainerClientData.steps(clientId), queryFn: () => trainerApi.clientSteps(clientId) },
      { queryKey: queryKeys.trainerClientData.sessions(clientId, 0, 200), queryFn: () => trainerApi.clientWorkoutSessions(clientId, 0, 200) },
    ],
  });
  const [mealsQ, weightsQ, stepsQ, sessionsQ] = results;
  const goalsQ = useQuery({ queryKey: queryKeys.trainerClientData.nutritionGoals(clientId), queryFn: () => trainerApi.clientNutritionGoals(clientId) });

  const raw: RawData = useMemo(
    () => ({ meals: mealsQ.data ?? [], weights: weightsQ.data ?? [], water: [], steps: stepsQ.data ?? [], sessions: sessionsQ.data?.content ?? [] }),
    [mealsQ.data, weightsQ.data, stepsQ.data, sessionsQ.data],
  );
  const calorieGoal = goalsQ.data?.dailyCalorieGoal ?? null;
  const stats = useMemo(
    () => buildPeriodStats({ raw, period: state.period, start: state.start, now: new Date(), goals: { calories: calorieGoal, steps: null, weightKg: null } }),
    [raw, state.period, state.start, calorieGoal],
  );

  if (results.some((r) => r.isLoading)) {
    return (
      <div className="flex flex-col gap-5">
        <Skeleton variant="card" className="h-10 w-64" />
        <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">
          {[0, 1, 2, 3, 4, 5].map((i) => <Skeleton key={i} variant="card" className="h-28" />)}
        </div>
        <Skeleton variant="chart" />
      </div>
    );
  }
  if (results.some((r) => r.isError)) return <ErrorState inline onRetry={() => results.forEach((r) => r.refetch())} />;

  return (
    <div className="flex flex-col gap-5">
      <div>
        <PeriodControl state={state} onChange={setState} stacked={phone} />
      </div>
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
