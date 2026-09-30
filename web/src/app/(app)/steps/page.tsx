"use client";

import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { Fab } from "@/components/ds";
import { useTranslations } from "next-intl";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { settingsApi } from "@/features/settings/api";
import { stepsApi } from "@/features/steps/api";
import { EditStepsDrawer } from "@/features/steps/components/EditStepsDrawer";
import { StepsHero } from "@/features/steps/components/StepsHero";
import { StepsStats } from "@/features/steps/components/StepsStats";
import { StepsTrendCard } from "@/features/steps/components/StepsTrendCard";
import { stepsWindow } from "@/features/steps/stats";
import { effectiveDailyStepGoal } from "@/features/steps/walking";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";

/**
 * The steps page (W4.6, W4-C): the hero — the day's count, what is left to the goal, "Szerkesztés" — three stat cards
 * beside it (`1fr | 0.5fr × 3` from 1280) and "Az elmúlt 14 nap" below. The day comes from the top bar's date stepper.
 */
export default function StepsPage() {
  const t = useTranslations("steps");
  const { date } = useDateStore();
  const phone = useMediaQuery("(max-width: 767px)");
  const [editing, setEditing] = useState(false);
  const dateStr = format(date, "yyyy-MM-dd");

  const stepsQ = useQuery({ queryKey: queryKeys.steps.all(), queryFn: stepsApi.list });
  const settingsQ = useQuery({ queryKey: queryKeys.settings.all(), queryFn: settingsApi.get, staleTime: 5 * 60_000 });
  const entries = useMemo(() => stepsQ.data ?? [], [stepsQ.data]);
  const goal = effectiveDailyStepGoal(settingsQ.data);

  if (stepsQ.isLoading) return <Skeleton variant="card" className="h-80" />;
  if (stepsQ.isError) return <ErrorState onRetry={() => stepsQ.refetch()} />;

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const windowEnd = date.getTime() > today.getTime() ? today : date;
  const stats = stepsWindow(entries, goal, windowEnd, now);
  const entry = entries.find((e) => e.date === dateStr) ?? null;
  const isToday = dateStr === format(now, "yyyy-MM-dd");

  return (
    <div className="flex flex-col gap-5">
      <div className="grid grid-cols-3 gap-2 md:gap-4 xl:grid-cols-[1fr_0.5fr_0.5fr_0.5fr]">
        <div className="col-span-3 xl:col-span-1">
          <StepsHero steps={entry?.steps ?? 0} goal={goal} isToday={isToday} date={date} onEdit={() => setEditing(true)} />
        </div>
        <StepsStats stats={stats} />
      </div>
      <StepsTrendCard window={stats} goal={goal} />

      {phone && <Fab icon="edit" label={t("fabEdit")} aria-label={t("edit")} onClick={() => setEditing(true)} />}
      {editing && <EditStepsDrawer key={dateStr} date={date} entry={entry} onClose={() => setEditing(false)} />}
    </div>
  );
}
