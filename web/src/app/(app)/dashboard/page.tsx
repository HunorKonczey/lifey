"use client";

import { useQueries } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { queryKeys } from "@/lib/api/queryKeys";
import { statisticsApi } from "@/features/statistics/api";
import { settingsApi } from "@/features/settings/api";
import { weightApi } from "@/features/weight/api";
import { waterApi } from "@/features/water/api";
import { stepsApi } from "@/features/steps/api";
import { mealApi } from "@/features/nutrition/api";
import { workoutSessionApi, templateApi } from "@/features/workouts/api";
import { RecommendedWorkoutCard } from "@/features/workouts/components/RecommendedWorkoutCard";
import { recommendedTemplate } from "@/features/workouts/recommendation";
import { OnboardingBanner } from "@/components/app/OnboardingBanner";
import { HeroMetricCard } from "@/components/data/HeroMetricCard";
import { MacroRing } from "@/components/data/MacroRing";
import { StatCard } from "@/components/data/StatCard";
import { WaterCard } from "@/components/data/WaterCard";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import type { MealResponse } from "@/features/nutrition/types";
import type { WaterEntryResponse } from "@/features/water/types";
import type { DailyStepCountResponse } from "@/features/steps/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

function localDateStr(date: Date) {
  return format(date, "yyyy-MM-dd");
}

function filterToday<T extends { dateTime?: string; consumedAt?: string; date?: string }>(
  items: T[],
  dateStr: string,
): T[] {
  return items.filter((item) => {
    const ts = item.dateTime ?? item.consumedAt ?? null;
    if (ts) {
      return format(new Date(ts), "yyyy-MM-dd") === dateStr;
    }
    if (item.date) return item.date === dateStr;
    return false;
  });
}

export default function DashboardPage() {
  const t = useTranslations("dashboard");
  const { date } = useDateStore();
  const router = useRouter();
  const dateStr = localDateStr(date);

  const results = useQueries({
    queries: [
      {
        queryKey: queryKeys.statistics.daily(dateStr),
        queryFn: () => statisticsApi.daily(dateStr),
      },
      {
        queryKey: queryKeys.statistics.weekly(dateStr),
        queryFn: () => statisticsApi.weekly(dateStr),
      },
      {
        queryKey: queryKeys.settings.all(),
        queryFn: settingsApi.get,
        staleTime: 5 * 60_000,
      },
      {
        queryKey: queryKeys.weights.all(),
        queryFn: weightApi.list,
      },
      {
        queryKey: queryKeys.waterEntries.all(),
        queryFn: waterApi.entries.list,
      },
      {
        queryKey: queryKeys.waterSources.all(),
        queryFn: waterApi.sources.list,
      },
      {
        queryKey: queryKeys.steps.all(),
        queryFn: stepsApi.list,
      },
      {
        queryKey: queryKeys.meals.all(),
        queryFn: mealApi.list,
      },
      {
        queryKey: queryKeys.workoutSessions.all(),
        queryFn: workoutSessionApi.list,
      },
      {
        queryKey: queryKeys.workoutTemplates.all(),
        queryFn: templateApi.list,
      },
    ],
  });

  const [
    statsQ,
    weeklyStatsQ,
    settingsQ,
    weightsQ,
    waterEntriesQ,
    waterSourcesQ,
    stepsQ,
    mealsQ,
    sessionsQ,
    templatesQ,
  ] = results;

  const weeklyStats = weeklyStatsQ.data;
  const settings = settingsQ.data;
  const todayMeals = mealsQ.data ? filterToday(mealsQ.data as MealResponse[], dateStr) : [];
  const todayWater = waterEntriesQ.data
    ? filterToday(waterEntriesQ.data as WaterEntryResponse[], dateStr)
    : [];
  const todaySteps = stepsQ.data
    ? (filterToday(stepsQ.data as DailyStepCountResponse[], dateStr)[0] ?? null)
    : null;
  // The API list isn't guaranteed to be date-sorted, so sort before taking the
  // newest — otherwise we'd show whatever entry happens to be last in insertion order.
  const latestWeight = weightsQ.data
    ? ([...weightsQ.data].sort((a, b) => a.date.localeCompare(b.date)).at(-1) ?? null)
    : null;
  const sessionsDesc = (sessionsQ.data ?? [])
    .slice()
    .sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());
  const recentSessions = sessionsDesc.slice(0, 5);
  const recommended = recommendedTemplate(sessionsDesc, templatesQ.data ?? []);

  const todayEntries = todayMeals.flatMap((m) => m.entries);
  const totalKcal = todayEntries.reduce((s, e) => s + e.calories, 0);
  const totalProtein = todayEntries.reduce((s, e) => s + e.protein, 0);
  const totalCarbs = todayEntries.reduce((s, e) => s + e.carbs, 0);
  const totalFat = todayEntries.reduce((s, e) => s + e.fat, 0);
  const totalWaterL = todayWater.reduce((s, e) => s + e.volumeLiters, 0);

  const isLoading = statsQ.isLoading || weeklyStatsQ.isLoading || settingsQ.isLoading;
  const hasError = statsQ.isError || weeklyStatsQ.isError || settingsQ.isError;

  if (isLoading) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton variant="card" className="h-40" />
        <div className="grid grid-cols-3 gap-4">
          <Skeleton variant="card" className="h-32" />
          <Skeleton variant="card" className="h-32" />
          <Skeleton variant="card" className="h-32" />
        </div>
        <div className="grid grid-cols-3 gap-4">
          <Skeleton variant="card" className="h-40" />
          <Skeleton variant="card" className="h-40" />
          <Skeleton variant="card" className="h-40" />
        </div>
      </div>
    );
  }

  if (hasError) {
    return (
      <ErrorState
        onRetry={() => {
          statsQ.refetch();
          weeklyStatsQ.refetch();
          settingsQ.refetch();
        }}
      />
    );
  }

  return (
    <div className="flex flex-col gap-4">
      {recommended && (
        <RecommendedWorkoutCard
          template={recommended}
          onStart={() => router.push(`/workouts?start=${recommended.id}`)}
        />
      )}
      <OnboardingBanner />
      <div className="flex gap-6">
      {/* Main column */}
      <div className="flex flex-col gap-4 flex-1 min-w-0">

        {/* Hero calorie card */}
        <HeroMetricCard value={totalKcal} goal={settings?.dailyCalorieGoal} />

        {!settings?.dailyCalorieGoal && !settings?.dailyProteinGoal && (
          <Link
            href="/settings"
            className="text-sm font-semibold -mt-2 hover:underline"
            style={{ color: "var(--primary)" }}
          >
            {t("setGoalsHint")}
          </Link>
        )}

        {/* Macro row */}
        <div className="grid grid-cols-3 gap-4">
          <div className="rounded-[var(--r-card)] p-4 flex justify-center" style={{ background: "var(--surface)" }}>
            <MacroRing
              label={t("protein")}
              value={totalProtein}
              goal={settings?.dailyProteinGoal}
              color="var(--metric-protein)"
            />
          </div>
          <div className="rounded-[var(--r-card)] p-4 flex justify-center" style={{ background: "var(--surface)" }}>
            <MacroRing
              label={t("carbs")}
              value={totalCarbs}
              goal={settings?.dailyCarbsGoal}
              color="var(--metric-carbs)"
            />
          </div>
          <div className="rounded-[var(--r-card)] p-4 flex justify-center" style={{ background: "var(--surface)" }}>
            <MacroRing
              label={t("fat")}
              value={totalFat}
              goal={settings?.dailyFatGoal}
              color="var(--metric-fat)"
            />
          </div>
        </div>

        {/* Water / Steps / Weight row */}
        <div className="grid grid-cols-3 gap-4">
          {waterEntriesQ.isLoading ? (
            <Skeleton variant="card" className="h-40" />
          ) : (
            <WaterCard
              currentLiters={totalWaterL}
              goalLiters={settings?.dailyWaterGoalLiters ?? 2.5}
              sources={waterSourcesQ.data ?? []}
              date={date}
            />
          )}

          {stepsQ.isLoading ? (
            <Skeleton variant="card" className="h-40" />
          ) : (
            <StatCard
              label={t("steps")}
              value={todaySteps?.steps ?? 0}
              icon="directions_walk"
              color="var(--metric-steps)"
              ratio={
                settings?.dailyStepGoal
                  ? (todaySteps?.steps ?? 0) / settings.dailyStepGoal
                  : undefined
              }
              goalReached={(todaySteps?.steps ?? 0) >= (settings?.dailyStepGoal ?? 10000)}
              subtitle={t("goal", { value: (settings?.dailyStepGoal ?? 10000).toLocaleString() })}
              onClick={() => router.push("/steps")}
            />
          )}

          {weightsQ.isLoading ? (
            <Skeleton variant="card" className="h-40" />
          ) : (
            <StatCard
              label={t("weight")}
              value={latestWeight ? latestWeight.weight.toFixed(1) : "—"}
              unit={latestWeight ? "kg" : ""}
              icon="monitor_weight"
              color="var(--metric-weight)"
              subtitle={latestWeight ? latestWeight.date : t("noEntryYet")}
              onClick={() => router.push("/weight")}
            />
          )}
        </div>

        {/* Recent workouts */}
        <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
          <p className="text-sm font-bold mb-3">{t("recentWorkouts")}</p>
          {sessionsQ.isLoading ? (
            <Skeleton variant="table" />
          ) : recentSessions.length === 0 ? (
            <p className="text-sm py-4 text-center" style={{ color: "var(--on-surface-variant)" }}>
              {t("noWorkoutsYet")}
            </p>
          ) : (
            <div className="flex flex-col gap-2">
              {recentSessions.map((s: WorkoutSessionResponse) => (
                <div
                  key={s.id}
                  className="flex items-center justify-between py-2 border-b last:border-0"
                  style={{ borderColor: "var(--outline)" }}
                >
                  <div>
                    <p className="text-sm font-semibold">
                      {s.templateName ?? (s.exercises.map((e) => e.exerciseName).join(", ") || t("workoutFallback"))}
                    </p>
                    <p className="text-xs" style={{ color: "var(--muted)" }}>
                      {format(new Date(s.startedAt), "MMM d, HH:mm")}
                    </p>
                  </div>
                  {s.finishedAt && (
                    <span className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
                      {Math.round(
                        (new Date(s.finishedAt).getTime() - new Date(s.startedAt).getTime()) / 60000,
                      )}{" "}
                      {t("minutes")}
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Right "This week" column */}
      <div
        className="hidden xl:flex flex-col gap-4 shrink-0"
        style={{ width: 268 }}
      >
        <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
          <p className="text-sm font-bold mb-3">{t("thisWeek")}</p>
          {weeklyStatsQ.isLoading ? (
            <Skeleton variant="text" />
          ) : (
            <div className="flex flex-col gap-3">
              <div className="flex justify-between text-sm">
                <span style={{ color: "var(--on-surface-variant)" }}>{t("avgCalories")}</span>
                <span className="font-semibold tabular">
                  {weeklyStats?.totalCalories != null
                    ? Math.round(weeklyStats.totalCalories / 7).toLocaleString()
                    : "—"}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span style={{ color: "var(--on-surface-variant)" }}>{t("workouts")}</span>
                <span className="font-semibold tabular">{weeklyStats?.workoutCount ?? "—"}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span style={{ color: "var(--on-surface-variant)" }}>{t("avgWater")}</span>
                <span className="font-semibold tabular">
                  {weeklyStats?.totalWater != null
                    ? (weeklyStats.totalWater / 7).toFixed(1) + " L"
                    : "—"}
                </span>
              </div>
              {weeklyStats?.latestWeight != null && (
                <div className="flex justify-between text-sm">
                  <span style={{ color: "var(--on-surface-variant)" }}>{t("latestWeight")}</span>
                  <span className="font-semibold tabular">{weeklyStats.latestWeight.toFixed(1)} kg</span>
                </div>
              )}
            </div>
          )}
        </div>

        <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
          <p className="text-sm font-bold mb-2">{t("streak")}</p>
          <p className="text-3xl font-extrabold tabular" style={{ color: "var(--primary)" }}>
            {recentSessions.length}
          </p>
          <p className="text-xs mt-1" style={{ color: "var(--on-surface-variant)" }}>
            {t("sessionsLogged")}
          </p>
        </div>
      </div>
      </div>
    </div>
  );
}
