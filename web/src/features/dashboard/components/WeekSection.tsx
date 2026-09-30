"use client";

import { useTranslations } from "next-intl";
import { useFormat } from "@/lib/i18n/format";
import { Skeleton } from "@/components/status/Skeleton";
import type { DashboardData } from "../useDashboardData";

/** W1.1 shell for the old "This week" + streak cards, stacked; replaced by
 *  `WeekCaloriesCard` (W1.8). */
export function WeekSection({ data }: { data: DashboardData }) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();
  const { weeklyStats, queries, streak } = data;

  return (
    <div className="flex flex-col gap-4">
      <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
        <p className="text-sm font-bold mb-3">{t("thisWeek")}</p>
        {queries.weeklyStatsQ.isLoading ? (
          <Skeleton variant="text" />
        ) : (
          <div className="flex flex-col gap-3">
            <div className="flex justify-between text-sm">
              <span style={{ color: "var(--on-surface-variant)" }}>{t("avgCalories")}</span>
              <span className="font-semibold tabular">
                {weeklyStats?.totalCalories != null ? fmt.number(Math.round(weeklyStats.totalCalories / 7)) : "—"}
              </span>
            </div>
            <div className="flex flex-col gap-0.5">
              <div className="flex justify-between text-sm">
                <span style={{ color: "var(--on-surface-variant)" }}>{t("workouts")}</span>
                <span className="font-semibold tabular">{weeklyStats?.workoutCount ?? "—"}</span>
              </div>
              {weeklyStats && weeklyStats.workoutCount != null && weeklyStats.workoutCount > 0 && (
                <p className="text-xs text-right" style={{ color: "var(--muted)" }}>
                  {t("workoutsBreakdown", { strength: weeklyStats.strengthWorkoutCount, cardio: weeklyStats.cardioWorkoutCount })}
                </p>
              )}
            </div>
            <div className="flex justify-between text-sm">
              <span style={{ color: "var(--on-surface-variant)" }}>{t("avgWater")}</span>
              <span className="font-semibold tabular">
                {weeklyStats?.totalWater != null ? fmt.number(weeklyStats.totalWater / 7, 1, 1) + " L" : "—"}
              </span>
            </div>
            {weeklyStats?.latestWeight != null && (
              <div className="flex justify-between text-sm">
                <span style={{ color: "var(--on-surface-variant)" }}>{t("latestWeight")}</span>
                <span className="font-semibold tabular">{fmt.number(weeklyStats.latestWeight, 1, 1)} kg</span>
              </div>
            )}
          </div>
        )}
      </div>

      <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
        <p className="text-sm font-bold mb-2">{t("streak")}</p>
        <p className="text-3xl font-extrabold tabular" style={{ color: "var(--primary)" }}>
          {streak}
        </p>
        <p className="text-xs mt-1" style={{ color: "var(--on-surface-variant)" }}>
          {t("streakDays", { count: streak })}
        </p>
      </div>
    </div>
  );
}
