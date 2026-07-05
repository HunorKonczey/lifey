"use client";

import { useMemo } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format, subDays } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { templateApi } from "@/features/workouts/api";
import { recipeApi } from "@/features/nutrition/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { KpiCard } from "@/components/data/KpiCard";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { useLocale } from "@/lib/hooks/useLocale";
import { UnassignButton } from "./UnassignButton";
import type { ContentType } from "../types";

const CONTENT_ICON: Record<ContentType, string> = { TEMPLATE: "fitness_center", RECIPE: "restaurant" };
const DATE_LOCALES = { en: enUS, hu } as const;

interface ClientOverviewTabProps {
  clientId: number;
}

export function ClientOverviewTab({ clientId }: ClientOverviewTabProps) {
  const t = useTranslations("admin.clientDetail");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];

  const statsQ = useQuery({
    queryKey: queryKeys.trainerClientData.statistics(clientId, "weekly"),
    queryFn: () => trainerApi.clientStatistics(clientId, "weekly"),
  });
  const weightsQ = useQuery({
    queryKey: queryKeys.trainerClientData.weights(clientId),
    queryFn: () => trainerApi.clientWeights(clientId),
  });
  const stepsQ = useQuery({
    queryKey: queryKeys.trainerClientData.steps(clientId),
    queryFn: () => trainerApi.clientSteps(clientId, format(subDays(new Date(), 6), "yyyy-MM-dd")),
  });
  const assignmentsQ = useQuery({
    queryKey: queryKeys.trainerAssignments.forClient(clientId),
    queryFn: () => trainerApi.assignmentsForClient(clientId),
  });
  const sessionsQ = useQuery({
    queryKey: queryKeys.trainerClientData.sessions(clientId, 0),
    queryFn: () => trainerApi.clientWorkoutSessions(clientId, 0, 4),
  });
  const templatesQ = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });
  const recipesQ = useQuery({ queryKey: queryKeys.recipes.all(), queryFn: recipeApi.list });

  const sourceName = useMemo(() => {
    const map = new Map<string, string>();
    (templatesQ.data ?? []).forEach((tpl) => map.set(`TEMPLATE:${tpl.id}`, tpl.name));
    (recipesQ.data ?? []).forEach((r) => map.set(`RECIPE:${r.id}`, r.name));
    return (type: ContentType, sourceId: number) => map.get(`${type}:${sourceId}`) ?? t("unknownContent");
  }, [templatesQ.data, recipesQ.data, t]);

  const sortedWeights = (weightsQ.data ?? []).slice().sort((a, b) => a.date.localeCompare(b.date));
  const latestWeight = sortedWeights.at(-1) ?? null;
  const prevWeight = sortedWeights.at(-2) ?? null;
  const weightDelta = latestWeight && prevWeight ? Number((latestWeight.weight - prevWeight.weight).toFixed(1)) : null;

  const avgSteps = stepsQ.data && stepsQ.data.length > 0
    ? Math.round(stepsQ.data.reduce((sum, s) => sum + s.steps, 0) / stepsQ.data.length)
    : 0;

  const isLoading = statsQ.isLoading || weightsQ.isLoading || stepsQ.isLoading || assignmentsQ.isLoading || sessionsQ.isLoading;
  const isError = statsQ.isError || weightsQ.isError || stepsQ.isError || assignmentsQ.isError || sessionsQ.isError;

  if (isLoading) {
    return (
      <div className="flex flex-col gap-3.5">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5">
          {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} variant="card" className="h-24" />)}
        </div>
        <Skeleton variant="card" className="h-72" />
      </div>
    );
  }

  if (isError) {
    return (
      <ErrorState
        inline
        onRetry={() => {
          statsQ.refetch();
          weightsQ.refetch();
          stepsQ.refetch();
          assignmentsQ.refetch();
          sessionsQ.refetch();
        }}
      />
    );
  }

  return (
    <div className="flex flex-col gap-3.5">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5">
        <KpiCard
          label={t("kpi.avgCalories")}
          value={`${Math.round((statsQ.data?.totalCalories ?? 0) / 7).toLocaleString()} kcal`}
          icon="local_fire_department"
          color="var(--metric-kcal)"
        />
        <KpiCard
          label={t("kpi.currentWeight")}
          value={latestWeight ? `${latestWeight.weight.toFixed(1)} kg` : "—"}
          icon="monitor_weight"
          color="var(--metric-weight)"
          delta={weightDelta}
          higherIsBetter={false}
          deltaUnit=" kg"
        />
        <KpiCard
          label={t("kpi.workoutsPerWeek")}
          value={String(statsQ.data?.workoutCount ?? 0)}
          icon="fitness_center"
          color="var(--tertiary)"
        />
        <KpiCard
          label={t("kpi.avgSteps")}
          value={avgSteps.toLocaleString()}
          icon="directions_walk"
          color="var(--metric-steps)"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-[1fr_1.35fr] gap-3.5 items-start">
        <div className="rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
          <p className="text-base font-extrabold mb-3.5" style={{ color: "var(--on-surface)" }}>
            {t("assignedPlans")}
          </p>
          {!assignmentsQ.data || assignmentsQ.data.length === 0 ? (
            <p className="text-xs" style={{ color: "var(--muted)" }}>{t("noAssignedPlans")}</p>
          ) : (
            <div className="flex flex-col gap-2">
              {assignmentsQ.data.map((a) => (
                <div key={a.id} className="rounded-[15px] px-3.5 py-3 flex items-center gap-3" style={{ background: "var(--surface-container)" }}>
                  <div
                    className="w-[38px] h-[38px] rounded-xl flex items-center justify-center shrink-0"
                    style={{ background: "var(--surface-high)", color: "var(--tertiary)" }}
                  >
                    <span className="material-symbols-rounded text-lg" style={{ fontVariationSettings: "'FILL' 1" }}>
                      {CONTENT_ICON[a.contentType]}
                    </span>
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                      {sourceName(a.contentType, a.sourceId)}
                    </p>
                    <p className="text-[11px] mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                      {t(a.contentType === "TEMPLATE" ? "planTypeTemplate" : "planTypeRecipe")}
                    </p>
                  </div>
                  <span className="text-[11.5px] tabular shrink-0" style={{ color: "var(--muted)" }}>
                    {format(new Date(a.assignedAt), "MMM d.", { locale: dateLocale })}
                  </span>
                  <UnassignButton
                    assignmentId={a.id}
                    clientId={clientId}
                    contentType={a.contentType}
                    sourceId={a.sourceId}
                    contentName={sourceName(a.contentType, a.sourceId)}
                  />
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
          <p className="text-base font-extrabold mb-0.5" style={{ color: "var(--on-surface)" }}>
            {t("workouts")}
          </p>
          <p className="text-[11.5px] mb-3.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("workoutsHint")}
          </p>
          {!sessionsQ.data || sessionsQ.data.content.length === 0 ? (
            <p className="text-xs" style={{ color: "var(--muted)" }}>{t("noSessions")}</p>
          ) : (
            <div className="flex flex-col gap-2">
              {sessionsQ.data.content.map((s) => {
                const volume = s.sets.reduce((sum, set) => sum + set.reps * set.weight, 0);
                return (
                  <div key={s.id} className="rounded-[15px] px-3.5 py-3 flex items-center gap-3.5" style={{ background: "var(--surface-container)" }}>
                    <span className="text-xs tabular w-[52px] shrink-0" style={{ color: "var(--on-surface-variant)" }}>
                      {format(new Date(s.startedAt), "MMM d.", { locale: dateLocale })}
                    </span>
                    <div className="flex-1 min-w-0">
                      <p className="text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                        {s.exercises[0]?.exerciseName ?? t("freeWorkout")}
                      </p>
                      <p className="text-[11px] mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                        {t("sessionSummary", { count: s.exercises.length, volume: Math.round(volume).toLocaleString() })}
                      </p>
                    </div>
                    {s.templateName && (
                      <span
                        className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[11px] font-extrabold px-2.5 py-1.5 shrink-0"
                        style={{ background: "var(--tertiary-container)", color: "var(--on-tertiary-container)" }}
                      >
                        <span className="material-symbols-rounded text-sm">assignment</span>
                        {s.templateName}
                      </span>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
