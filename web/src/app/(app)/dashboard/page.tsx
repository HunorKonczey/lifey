"use client";

import { useQueries } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { format } from "date-fns";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { queryKeys } from "@/lib/api/queryKeys";
import { statisticsApi } from "@/features/statistics/api";
import { settingsApi } from "@/features/settings/api";
import { weightApi } from "@/features/weight/api";
import { waterApi } from "@/features/water/api";
import { stepsApi } from "@/features/steps/api";
import { mealApi } from "@/features/nutrition/api";
import { workoutSessionApi } from "@/features/workouts/api";
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
    ],
  });

  const [statsQ, settingsQ, weightsQ, waterEntriesQ, waterSourcesQ, stepsQ, mealsQ, sessionsQ] =
    results;

  const stats = statsQ.data;
  const settings = settingsQ.data;
  const todayMeals = mealsQ.data ? filterToday(mealsQ.data as MealResponse[], dateStr) : [];
  const todayWater = waterEntriesQ.data
    ? filterToday(waterEntriesQ.data as WaterEntryResponse[], dateStr)
    : [];
  const todaySteps = stepsQ.data
    ? (filterToday(stepsQ.data as DailyStepCountResponse[], dateStr)[0] ?? null)
    : null;
  const latestWeight = weightsQ.data?.at(-1) ?? null;
  const recentSessions = sessionsQ.data?.slice(-5).reverse() ?? [];

  const totalKcal = todayMeals.flatMap((m) => m.entries).reduce((s, e) => s + e.calories, 0);
  const totalProtein = todayMeals.flatMap((m) => m.entries).reduce((s, e) => s + e.protein, 0);
  const totalCarbs = stats?.totalCarbs ?? 0;
  const totalFat = stats?.totalFat ?? 0;
  const totalWaterL = todayWater.reduce((s, e) => s + e.volumeLiters, 0);

  const isLoading = statsQ.isLoading || settingsQ.isLoading;
  const hasError = statsQ.isError || settingsQ.isError;

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
          settingsQ.refetch();
        }}
      />
    );
  }

  return (
    <div className="flex gap-6">
      {/* Main column */}
      <div className="flex flex-col gap-4 flex-1 min-w-0">

        {/* Hero calorie card */}
        <HeroMetricCard
          value={totalKcal}
          goal={settings?.dailyCalorieGoal ?? 2000}
        />

        {/* Macro row */}
        <div className="grid grid-cols-3 gap-4">
          <div className="rounded-[var(--r-card)] p-4 flex justify-center" style={{ background: "var(--surface)" }}>
            <MacroRing
              label="Protein"
              value={totalProtein}
              goal={settings?.dailyProteinGoal ?? 150}
              color="var(--metric-protein)"
            />
          </div>
          <div className="rounded-[var(--r-card)] p-4 flex justify-center" style={{ background: "var(--surface)" }}>
            <MacroRing
              label="Carbs"
              value={totalCarbs}
              goal={settings?.dailyCarbsGoal ?? 250}
              color="var(--metric-carbs)"
            />
          </div>
          <div className="rounded-[var(--r-card)] p-4 flex justify-center" style={{ background: "var(--surface)" }}>
            <MacroRing
              label="Fat"
              value={totalFat}
              goal={settings?.dailyFatGoal ?? 65}
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
            />
          )}

          {stepsQ.isLoading ? (
            <Skeleton variant="card" className="h-40" />
          ) : (
            <StatCard
              label="Steps"
              value={todaySteps?.steps ?? 0}
              icon="directions_walk"
              color="var(--metric-steps)"
              ratio={
                settings?.dailyStepGoal
                  ? (todaySteps?.steps ?? 0) / settings.dailyStepGoal
                  : undefined
              }
              goalReached={(todaySteps?.steps ?? 0) >= (settings?.dailyStepGoal ?? 10000)}
              subtitle={`Goal: ${(settings?.dailyStepGoal ?? 10000).toLocaleString()}`}
              onClick={() => router.push("/steps")}
            />
          )}

          {weightsQ.isLoading ? (
            <Skeleton variant="card" className="h-40" />
          ) : (
            <StatCard
              label="Weight"
              value={latestWeight?.weight ?? "—"}
              unit={latestWeight ? "kg" : ""}
              icon="monitor_weight"
              color="var(--metric-weight)"
              subtitle={latestWeight ? latestWeight.date : "No entry yet"}
              onClick={() => router.push("/weight")}
            />
          )}
        </div>

        {/* Recent workouts */}
        <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
          <p className="text-sm font-bold mb-3">Recent workouts</p>
          {sessionsQ.isLoading ? (
            <Skeleton variant="table" />
          ) : recentSessions.length === 0 ? (
            <p className="text-sm py-4 text-center" style={{ color: "var(--on-surface-variant)" }}>
              No workouts yet
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
                      {s.exercises.map((e) => e.exerciseName).join(", ") || "Workout"}
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
                      min
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
          <p className="text-sm font-bold mb-3">This week</p>
          {statsQ.isLoading ? (
            <Skeleton variant="text" />
          ) : (
            <div className="flex flex-col gap-3">
              <div className="flex justify-between text-sm">
                <span style={{ color: "var(--on-surface-variant)" }}>Avg calories</span>
                <span className="font-semibold tabular">
                  {stats?.totalCalories != null
                    ? Math.round(stats.totalCalories / 7).toLocaleString()
                    : "—"}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span style={{ color: "var(--on-surface-variant)" }}>Workouts</span>
                <span className="font-semibold tabular">{stats?.workoutCount ?? "—"}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span style={{ color: "var(--on-surface-variant)" }}>Avg water</span>
                <span className="font-semibold tabular">
                  {stats?.totalWater != null
                    ? (stats.totalWater / 7).toFixed(1) + " L"
                    : "—"}
                </span>
              </div>
              {stats?.latestWeight != null && (
                <div className="flex justify-between text-sm">
                  <span style={{ color: "var(--on-surface-variant)" }}>Latest weight</span>
                  <span className="font-semibold tabular">{stats.latestWeight} kg</span>
                </div>
              )}
            </div>
          )}
        </div>

        <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
          <p className="text-sm font-bold mb-2">Streak</p>
          <p className="text-3xl font-extrabold tabular" style={{ color: "var(--primary)" }}>
            {recentSessions.length}
          </p>
          <p className="text-xs mt-1" style={{ color: "var(--on-surface-variant)" }}>
            sessions logged
          </p>
        </div>
      </div>
    </div>
  );
}
