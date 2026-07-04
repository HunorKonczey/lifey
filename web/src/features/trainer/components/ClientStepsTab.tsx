"use client";

import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format, subDays } from "date-fns";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { TimeSeriesChart } from "@/components/data/TimeSeriesChartLazy";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";

interface ClientStepsTabProps {
  clientId: number;
}

export function ClientStepsTab({ clientId }: ClientStepsTabProps) {
  const t = useTranslations("admin.clientDetail");

  const stepsQ = useQuery({
    queryKey: [...queryKeys.trainerClientData.steps(clientId), "30d"],
    queryFn: () => trainerApi.clientSteps(clientId, format(subDays(new Date(), 29), "yyyy-MM-dd")),
  });

  if (stepsQ.isLoading) return <Skeleton variant="chart" />;
  if (stepsQ.isError) return <ErrorState inline onRetry={() => stepsQ.refetch()} />;

  const sorted = (stepsQ.data ?? []).slice().sort((a, b) => a.date.localeCompare(b.date));
  if (sorted.length === 0) {
    return <EmptyState icon="directions_walk" title={t("noSteps")} body={t("noStepsBody")} />;
  }

  const chartData = sorted.map((s) => ({ date: format(new Date(s.date), "MMM d"), value: s.steps }));
  const history = sorted.slice().reverse();

  return (
    <div className="flex flex-col lg:flex-row gap-3.5">
      <div className="flex-1 min-w-0 rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
        <p className="text-sm font-bold mb-4" style={{ color: "var(--on-surface)" }}>{t("last30Days")}</p>
        <TimeSeriesChart data={chartData} color="var(--metric-steps)" />
      </div>
      <div className="w-full lg:w-[280px] shrink-0 rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
        <p className="text-sm font-bold mb-3" style={{ color: "var(--on-surface)" }}>{t("history")}</p>
        <div className="flex flex-col max-h-[320px] overflow-y-auto">
          {history.map((s) => (
            <div key={s.id} className="flex items-center justify-between py-2" style={{ borderBottom: "1px solid var(--outline)" }}>
              <span className="text-sm tabular" style={{ color: "var(--on-surface-variant)" }}>
                {format(new Date(s.date), "MMM d, yyyy")}
              </span>
              <span className="text-sm font-semibold tabular" style={{ color: "var(--on-surface)" }}>
                {s.steps.toLocaleString()}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
