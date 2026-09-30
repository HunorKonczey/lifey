"use client";

import { useQueries } from "@tanstack/react-query";
import { format } from "date-fns";
import { queryKeys } from "@/lib/api/queryKeys";
import { loggingStreak } from "@/features/statistics/streak";
import { statisticsApi } from "@/features/statistics/api";
import { settingsApi } from "@/features/settings/api";
import { weightApi } from "@/features/weight/api";
import { waterApi } from "@/features/water/api";
import { stepsApi } from "@/features/steps/api";
import { mealApi } from "@/features/nutrition/api";
import { workoutSessionApi, templateApi } from "@/features/workouts/api";
import { recommendedTemplate } from "@/features/workouts/recommendation";
import type { MealResponse } from "@/features/nutrition/types";
import type { WaterEntryResponse } from "@/features/water/types";
import type { DailyStepCountResponse } from "@/features/steps/types";

export function localDateStr(date: Date) {
  return format(date, "yyyy-MM-dd");
}

/** Items whose timestamp (or plain `date`) falls on the local day `dateStr`. */
export function filterToday<T extends { dateTime?: string; consumedAt?: string; date?: string }>(
  items: T[],
  dateStr: string,
): T[] {
  return items.filter((item) => {
    const ts = item.dateTime ?? item.consumedAt ?? null;
    if (ts) return format(new Date(ts), "yyyy-MM-dd") === dateStr;
    if (item.date) return item.date === dateStr;
    return false;
  });
}

/**
 * Every query the dashboard needs, plus the day's derived figures, in one
 * place — the page composes section components from this instead of each
 * section re-deriving "today's meals" (W1.1). Sections still read their own
 * shape from it; no section fetches on its own.
 */
export function useDashboardData(date: Date) {
  const dateStr = localDateStr(date);

  const [statsQ, weeklyStatsQ, settingsQ, weightsQ, waterEntriesQ, waterSourcesQ, stepsQ, mealsQ, sessionsQ, templatesQ] =
    useQueries({
      queries: [
        { queryKey: queryKeys.statistics.daily(dateStr), queryFn: () => statisticsApi.daily(dateStr) },
        { queryKey: queryKeys.statistics.weekly(dateStr), queryFn: () => statisticsApi.weekly(dateStr) },
        { queryKey: queryKeys.settings.all(), queryFn: settingsApi.get, staleTime: 5 * 60_000 },
        { queryKey: queryKeys.weights.all(), queryFn: weightApi.list },
        { queryKey: queryKeys.waterEntries.all(), queryFn: waterApi.entries.list },
        { queryKey: queryKeys.waterSources.all(), queryFn: waterApi.sources.list },
        { queryKey: queryKeys.steps.all(), queryFn: stepsApi.list },
        { queryKey: queryKeys.meals.all(), queryFn: mealApi.list },
        { queryKey: queryKeys.workoutSessions.all(), queryFn: workoutSessionApi.list },
        { queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list },
      ],
    });

  const meals = (mealsQ.data as MealResponse[] | undefined) ?? [];
  const todayMeals = filterToday(meals, dateStr);
  const todayWater = filterToday((waterEntriesQ.data as WaterEntryResponse[] | undefined) ?? [], dateStr);
  const todaySteps = stepsQ.data
    ? (filterToday((stepsQ.data as DailyStepCountResponse[] | undefined) ?? [], dateStr)[0] ?? null)
    : null;

  // The API list isn't guaranteed to be date-sorted, so sort before taking the
  // newest — otherwise we'd show whatever entry happens to be last in insertion order.
  const weightsAsc = weightsQ.data ? [...weightsQ.data].sort((a, b) => a.date.localeCompare(b.date)) : [];
  const latestWeight = weightsAsc.at(-1) ?? null;

  const sessionsDesc = (sessionsQ.data ?? [])
    .slice()
    .sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());
  const recommended = recommendedTemplate(sessionsDesc, templatesQ.data ?? []);
  const streak = loggingStreak([...meals.map((m) => m.dateTime), ...sessionsDesc.map((s) => s.startedAt)]);

  const todayEntries = todayMeals.flatMap((m) => m.entries);
  const totals = {
    kcal: todayEntries.reduce((s, e) => s + e.calories, 0),
    protein: todayEntries.reduce((s, e) => s + e.protein, 0),
    carbs: todayEntries.reduce((s, e) => s + e.carbs, 0),
    fat: todayEntries.reduce((s, e) => s + e.fat, 0),
    waterL: todayWater.reduce((s, e) => s + e.volumeLiters, 0),
  };

  return {
    dateStr,
    queries: { statsQ, weeklyStatsQ, settingsQ, weightsQ, waterEntriesQ, waterSourcesQ, stepsQ, mealsQ, sessionsQ, templatesQ },
    settings: settingsQ.data,
    weeklyStats: weeklyStatsQ.data,
    meals,
    todayMeals,
    todayWater,
    todaySteps,
    weightsAsc,
    latestWeight,
    sessionsDesc,
    templates: templatesQ.data ?? [],
    recommended,
    streak,
    totals,
    isLoading: statsQ.isLoading || weeklyStatsQ.isLoading || settingsQ.isLoading,
    hasError: statsQ.isError || weeklyStatsQ.isError || settingsQ.isError,
    refetchCore: () => {
      statsQ.refetch();
      weeklyStatsQ.refetch();
      settingsQ.refetch();
    },
  };
}

export type DashboardData = ReturnType<typeof useDashboardData>;
