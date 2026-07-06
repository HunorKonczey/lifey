"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format, subMonths, subYears } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { KpiCard } from "@/components/data/KpiCard";
import { TimeSeriesChart } from "@/components/data/TimeSeriesChartLazy";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { useLocale } from "@/lib/hooks/useLocale";

const DATE_LOCALES = { en: enUS, hu } as const;

type Period = "daily" | "weekly" | "monthly";

interface ClientStatisticsTabProps {
  clientId: number;
}

export function ClientStatisticsTab({ clientId }: ClientStatisticsTabProps) {
  const t = useTranslations("admin.clientDetail");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const [period, setPeriod] = useState<Period>("weekly");

  const PERIOD_OPTIONS: { value: Period; label: string }[] = [
    { value: "daily", label: t("period.daily") },
    { value: "weekly", label: t("period.weekly") },
    { value: "monthly", label: t("period.monthly") },
  ];

  const statsQ = useQuery({
    queryKey: queryKeys.trainerClientData.statistics(clientId, period),
    queryFn: () => trainerApi.clientStatistics(clientId, period),
  });

  const weightsFrom = period === "monthly" ? subYears(new Date(), 1) : subMonths(new Date(), 3);
  const weightsQ = useQuery({
    queryKey: [...queryKeys.trainerClientData.weights(clientId), period],
    queryFn: () => trainerApi.clientWeights(clientId, format(weightsFrom, "yyyy-MM-dd")),
  });

  if (statsQ.isLoading || weightsQ.isLoading) {
    return (
      <div className="flex flex-col gap-3.5">
        <Skeleton variant="card" className="h-10 w-64" />
        <div className="grid grid-cols-3 gap-3.5">
          {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} variant="card" className="h-24" />)}
        </div>
        <Skeleton variant="chart" />
      </div>
    );
  }

  if (statsQ.isError || weightsQ.isError) {
    return <ErrorState inline onRetry={() => { statsQ.refetch(); weightsQ.refetch(); }} />;
  }

  const sortedWeights = (weightsQ.data ?? []).slice().sort((a, b) => a.date.localeCompare(b.date));
  const chartData = sortedWeights.map((w) => ({ date: format(new Date(w.date), "MMM d", { locale: dateLocale }), value: w.weight }));

  return (
    <div className="flex flex-col gap-3.5">
      <SegmentedControl
        options={PERIOD_OPTIONS}
        value={period}
        onChange={setPeriod}
        activeBackground="var(--tertiary)"
        activeColor="#161611"
      />

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
        <KpiCard
          label={t("kpi.calories")}
          value={`${(statsQ.data?.totalCalories ?? 0).toLocaleString()} kcal`}
          icon="local_fire_department"
          color="var(--metric-kcal)"
        />
        <KpiCard
          label={t("kpi.workouts")}
          value={String(statsQ.data?.workoutCount ?? 0)}
          icon="fitness_center"
          color="var(--tertiary)"
        />
        <KpiCard
          label={t("kpi.weight")}
          value={statsQ.data?.latestWeight != null ? `${statsQ.data.latestWeight.toFixed(1)} kg` : "—"}
          icon="monitor_weight"
          color="var(--metric-weight)"
        />
      </div>

      <div className="rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
        <p className="text-sm font-bold mb-4" style={{ color: "var(--on-surface)" }}>{t("weightTrend")}</p>
        {chartData.length > 0 ? (
          <TimeSeriesChart data={chartData} color="var(--metric-weight)" unit=" kg" />
        ) : (
          <p className="text-sm text-center py-16" style={{ color: "var(--muted)" }}>{t("noWeightEntries")}</p>
        )}
      </div>
    </div>
  );
}
