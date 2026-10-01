"use client";

import { useMemo } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format, subDays } from "date-fns";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { StepsStats } from "@/features/steps/components/StepsStats";
import { StepsTrendCard } from "@/features/steps/components/StepsTrendCard";
import { stepsWindow } from "@/features/steps/stats";
import { queryKeys } from "@/lib/api/queryKeys";
import { trainerApi } from "../api";

interface ClientStepsTabProps {
  clientId: number;
}

/**
 * The client's steps (W7-C): the last 14 days in the client's own chart — one colour, today dashed — and the average
 * and best-day cards. The trainer cannot read the client's step goal, so there is no goal line and no "goal days"
 * card (the "Cél módosítása" action stays unbuilt, D-W0.19).
 */
export function ClientStepsTab({ clientId }: ClientStepsTabProps) {
  const t = useTranslations("admin.clientDetail");
  const from = useMemo(() => format(subDays(new Date(), 29), "yyyy-MM-dd"), []);
  const stepsQ = useQuery({
    queryKey: [...queryKeys.trainerClientData.steps(clientId), "30d"],
    queryFn: () => trainerApi.clientSteps(clientId, from),
  });

  if (stepsQ.isLoading) return <Skeleton variant="chart" />;
  if (stepsQ.isError) return <ErrorState inline onRetry={() => stepsQ.refetch()} />;

  const entries = stepsQ.data ?? [];
  if (entries.length === 0) return <EmptyState icon="directions_walk" title={t("noSteps")} body={t("noStepsBody")} />;

  const now = new Date();
  const stats = stepsWindow(entries, 0, now, now);

  return (
    <div className="flex flex-col gap-5">
      <div className="grid grid-cols-2 gap-4">
        <StepsStats stats={stats} showGoal={false} />
      </div>
      <StepsTrendCard window={stats} goal={null} />
    </div>
  );
}
