"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useFormat } from "@/lib/i18n/format";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { StatCard } from "@/components/data/StatCard";
import { WaterCard } from "@/components/data/WaterCard";
import { Skeleton } from "@/components/status/Skeleton";
import type { DashboardData } from "../useDashboardData";

/** W1.1 shell for the Water / Steps / Weight row (old cards, unchanged). One
 *  column on phones — three was unreadable at 390 — replaced tile by tile in
 *  W1.5 and W1.7. */
export function TilesSection({ data }: { data: DashboardData }) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();
  const router = useRouter();
  const { date } = useDateStore();
  const { settings, totals, todaySteps, latestWeight, queries } = data;

  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
      {queries.waterEntriesQ.isLoading ? (
        <Skeleton variant="card" className="h-40" />
      ) : (
        <WaterCard
          currentLiters={totals.waterL}
          goalLiters={settings?.dailyWaterGoalLiters ?? 2.5}
          sources={queries.waterSourcesQ.data ?? []}
          date={date}
        />
      )}

      {queries.stepsQ.isLoading ? (
        <Skeleton variant="card" className="h-40" />
      ) : (
        <StatCard
          label={t("steps")}
          value={todaySteps?.steps ?? 0}
          icon="directions_walk"
          color="var(--metric-steps)"
          ratio={settings?.dailyStepGoal ? (todaySteps?.steps ?? 0) / settings.dailyStepGoal : undefined}
          goalReached={(todaySteps?.steps ?? 0) >= (settings?.dailyStepGoal ?? 10000)}
          subtitle={t("goal", { value: fmt.number(settings?.dailyStepGoal ?? 10000) })}
          onClick={() => router.push("/steps")}
        />
      )}

      {queries.weightsQ.isLoading ? (
        <Skeleton variant="card" className="h-40" />
      ) : (
        <StatCard
          label={t("weight")}
          value={latestWeight ? fmt.number(latestWeight.weight, 1, 1) : "—"}
          unit={latestWeight ? "kg" : ""}
          icon="monitor_weight"
          color="var(--metric-weight)"
          subtitle={latestWeight ? fmt.date(latestWeight.date, "dayYear") : t("noEntryYet")}
          onClick={() => router.push("/weight")}
        />
      )}
    </div>
  );
}
