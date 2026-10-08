"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format, subDays } from "date-fns";
import { Button, Card, Icon } from "@/components/ds";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { StepsStats } from "@/features/steps/components/StepsStats";
import { StepsTrendCard } from "@/features/steps/components/StepsTrendCard";
import { stepsWindow } from "@/features/steps/stats";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { trainerApi } from "../api";
import { StepGoalDrawer } from "./StepGoalDrawer";

interface ClientStepsTabProps {
  clientId: number;
  /** The client's own daily step goal, or null when they never set one. */
  stepGoal: number | null;
}

/**
 * The client's steps (W7-C): the last 14 days in the client's own chart — one colour, today dashed — and the average
 * and best-day cards. The goal line and the "goal days" card are the client's own step goal, which the client summary
 * carries since LIF-101; a client who never set one gets neither, never a made-up default. Above them a card names the
 * goal and "Cél módosítása" opens the trainer's editor for it (LIF-105, D-W0.19).
 */
export function ClientStepsTab({ clientId, stepGoal }: ClientStepsTabProps) {
  const t = useTranslations("admin.clientDetail");
  const fmt = useFormat();
  const [editingGoal, setEditingGoal] = useState(false);
  const from = useMemo(() => format(subDays(new Date(), 29), "yyyy-MM-dd"), []);
  const stepsQ = useQuery({
    queryKey: [...queryKeys.trainerClientData.steps(clientId), "30d"],
    queryFn: () => trainerApi.clientSteps(clientId, from),
  });

  if (stepsQ.isLoading) return <Skeleton variant="chart" />;
  if (stepsQ.isError) return <ErrorState inline onRetry={() => stepsQ.refetch()} />;

  const goalCard = (
    <Card variant="card" className="flex flex-wrap items-center gap-3" data-testid="step-goal-card">
      <Icon name="flag" size={22} color="var(--m-steps)" />
      <span className="flex min-w-0 flex-1 flex-col">
        <span style={{ fontWeight: 800 }}>{t("stepGoalTitle")}</span>
        <span className="type-body-s" style={{ color: "var(--text-2)" }} data-testid="step-goal-value">
          {stepGoal != null ? t("stepGoalValue", { steps: fmt.integer(stepGoal) }) : t("stepGoalNone")}
        </span>
      </span>
      <Button variant="secondary" onClick={() => setEditingGoal(true)} data-testid="step-goal-edit">
        {stepGoal != null ? t("stepGoalEdit") : t("stepGoalSet")}
      </Button>
    </Card>
  );
  const drawer = editingGoal && <StepGoalDrawer clientId={clientId} goal={stepGoal} onClose={() => setEditingGoal(false)} />;

  const entries = stepsQ.data ?? [];
  if (entries.length === 0) {
    return (
      <div className="flex flex-col gap-5">
        {goalCard}
        <EmptyState icon="directions_walk" title={t("noSteps")} body={t("noStepsBody")} />
        {drawer}
      </div>
    );
  }

  const now = new Date();
  const stats = stepsWindow(entries, stepGoal ?? 0, now, now);

  return (
    <div className="flex flex-col gap-5">
      {goalCard}
      <div className="grid grid-cols-2 gap-4">
        <StepsStats stats={stats} showGoal={stepGoal != null} />
      </div>
      <StepsTrendCard window={stats} goal={stepGoal} />
      {drawer}
    </div>
  );
}
