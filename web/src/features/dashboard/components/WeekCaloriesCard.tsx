"use client";

import { useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { LifeyBarChart, type BarChartDatum } from "@/components/ds/charts/LifeyBarChart.lazy";
import { useFormat } from "@/lib/format/useFormat";
import { weekDays, weekStats, type WeekDay, type WeekStats } from "../weekCalories";
import type { DashboardData } from "../useDashboardData";

export interface WeekCaloriesCardViewProps {
  days: WeekDay[];
  goalKcal: number | null;
  stats: WeekStats;
}

function Stat({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-baseline gap-1.5">
      <span className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>
        {label}
      </span>
      <span className="tabular" style={{ fontSize: 15, fontWeight: 800 }}>
        {children}
      </span>
    </div>
  );
}

/**
 * The dashboard's "last 7 days" card (W1.8, client-001): the average (today
 * left out — a half-logged day would drag it down), how many complete days
 * landed within goal, the workouts, and a 7-bar chart with a dashed goal line
 * and today as a dashed outline. Days with nothing logged draw no bar.
 */
export function WeekCaloriesCardView({ days, goalKcal, stats }: WeekCaloriesCardViewProps) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();

  const data: BarChartDatum[] = days.map((d) => ({
    label: d.isToday ? t("weekTodayShort") : fmt.weekdayShort(d.date),
    value: d.kcal > 0 ? d.kcal : null,
    isToday: d.isToday,
  }));

  return (
    <Card style={{ padding: "22px 24px" }} data-testid="week-calories">
      <div className="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-2">
        <h3 style={{ fontSize: 16, fontWeight: 800 }}>{t("weekTitle")}</h3>
        <div className="flex flex-wrap items-baseline gap-x-5 gap-y-1">
          <Stat label={t("weekAverage")}>{stats.averageKcal != null ? fmt.integer(stats.averageKcal, "kcal") : "—"}</Stat>
          {stats.withinGoal != null && (
            <Stat label={t("weekWithinGoal")}>{t("weekWithinValue", { n: stats.withinGoal, total: stats.completeDays })}</Stat>
          )}
          <Stat label={t("weekWorkouts")}>{stats.workouts}</Stat>
        </div>
      </div>
      <div className="mt-3">
        <LifeyBarChart
          aria-label={t("weekChartLabel")}
          data={data}
          color="var(--m-kcal)"
          goal={goalKcal ?? undefined}
          goalLabel={goalKcal != null ? t("weekGoalLabel", { goal: fmt.integer(goalKcal) }) : undefined}
          height={220}
        />
      </div>
    </Card>
  );
}

export function WeekCaloriesCard({ data }: { data: DashboardData }) {
  const now = new Date();
  const days = weekDays(data.meals, data.date, now);
  const goal = data.settings?.dailyCalorieGoal ?? null;
  const stats = weekStats(days, goal, data.sessionsDesc.map((s) => s.startedAt), now);
  return <WeekCaloriesCardView days={days} goalKcal={goal} stats={stats} />;
}
