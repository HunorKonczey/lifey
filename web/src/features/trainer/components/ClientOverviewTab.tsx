"use client";

import { useMemo } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { addDays, format, startOfWeek, subDays } from "date-fns";
import { Card, DeltaChip, Icon, MetricTile } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { templateApi } from "@/features/workouts/api";
import { recipeApi } from "@/features/nutrition/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { trainerApi } from "../api";
import { buildFeed, buildHeatmap, dailyAverages } from "../clientActivity";
import { weekSummary, weightChange } from "../clientSignals";
import { ActivityFeed } from "./ActivityFeed";
import { LoggingHeatmap } from "./LoggingHeatmap";
import { UnassignButton } from "./UnassignButton";
import { UpcomingSchedule } from "./UpcomingSchedule";
import type { ContentType } from "../types";

const CONTENT_ICON: Record<ContentType, string> = { TEMPLATE: "fitness_center", RECIPE: "restaurant" };
const HEATMAP_DAYS = 28;

interface ClientOverviewTabProps {
  clientId: number;
}

/**
 * The client overview (W7-B): four KPI tiles relative to the client's goals, the four-week logging heatmap with the
 * next scheduled workouts and the latest activity beside it, and the plans assigned to the client (kept from the old
 * page — unassigning must stay possible). Every number is derived from what the client logged; a missing goal or a
 * missing week just drops the bar, it never shows as zero.
 */
export function ClientOverviewTab({ clientId }: ClientOverviewTabProps) {
  const t = useTranslations("admin.clientDetail");
  const o = useTranslations("admin.clientDetail.overview");
  const fmt = useFormat();

  const today = useMemo(() => new Date(), []);
  const from = format(subDays(today, HEATMAP_DAYS + 6), "yyyy-MM-dd");
  const to = format(today, "yyyy-MM-dd");
  const weekStart = format(startOfWeek(today, { weekStartsOn: 1 }), "yyyy-MM-dd");
  const rangeEnd = format(addDays(new Date(weekStart + "T00:00:00"), 20), "yyyy-MM-dd");

  const mealsQ = useQuery({ queryKey: queryKeys.trainerClientData.meals(clientId, `${from}_${to}`), queryFn: () => trainerApi.clientMeals(clientId, from, to) });
  const weightsQ = useQuery({ queryKey: queryKeys.trainerClientData.weights(clientId), queryFn: () => trainerApi.clientWeights(clientId) });
  const sessionsQ = useQuery({ queryKey: queryKeys.trainerClientData.sessions(clientId, 0, 50), queryFn: () => trainerApi.clientWorkoutSessions(clientId, 0, 50) });
  const goalsQ = useQuery({ queryKey: queryKeys.trainerClientData.nutritionGoals(clientId), queryFn: () => trainerApi.clientNutritionGoals(clientId) });
  const calendarQ = useQuery({ queryKey: queryKeys.trainerCalendar.range(weekStart, rangeEnd), queryFn: () => trainerApi.calendarSessions(weekStart, rangeEnd) });
  const assignmentsQ = useQuery({ queryKey: queryKeys.trainerAssignments.forClient(clientId), queryFn: () => trainerApi.assignmentsForClient(clientId) });
  const templatesQ = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });
  const recipesQ = useQuery({ queryKey: queryKeys.recipes.all(), queryFn: recipeApi.list });

  const sourceName = useMemo(() => {
    const map = new Map<string, string>();
    (templatesQ.data ?? []).forEach((tpl) => map.set(`TEMPLATE:${tpl.id}`, tpl.name));
    (recipesQ.data ?? []).forEach((r) => map.set(`RECIPE:${r.id}`, r.name));
    return (type: ContentType, sourceId: number) => map.get(`${type}:${sourceId}`) ?? t("unknownContent");
  }, [templatesQ.data, recipesQ.data, t]);

  const meals = useMemo(() => mealsQ.data ?? [], [mealsQ.data]);
  const weights = useMemo(() => weightsQ.data ?? [], [weightsQ.data]);
  const sessions = useMemo(() => sessionsQ.data?.content ?? [], [sessionsQ.data]);

  const averages = useMemo(() => dailyAverages(meals, today), [meals, today]);
  const week = useMemo(() => weekSummary(calendarQ.data ?? [], clientId, weekStart, to), [calendarQ.data, clientId, weekStart, to]);
  const weight = useMemo(() => weightChange(weights.map((w) => ({ date: w.date, weightKg: w.weight })), today), [weights, today]);
  const heat = useMemo(() => buildHeatmap({ meals, sessions, weights }, today), [meals, sessions, weights, today]);
  const feed = useMemo(() => buildFeed({ meals, sessions, weights }, 5), [meals, sessions, weights]);
  const upcoming = useMemo(
    () => (calendarQ.data ?? []).filter((s) => s.clientId === clientId && s.status === "UPCOMING" && s.scheduledFor >= to).sort((a, b) => a.scheduledFor.localeCompare(b.scheduledFor) || (a.scheduledTime ?? "").localeCompare(b.scheduledTime ?? "")),
    [calendarQ.data, clientId, to],
  );

  const isLoading = mealsQ.isLoading || weightsQ.isLoading || sessionsQ.isLoading;
  const isError = mealsQ.isError || weightsQ.isError || sessionsQ.isError;

  if (isLoading) {
    return (
      <div className="flex flex-col gap-4">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} variant="card" className="h-32" />)}
        </div>
        <Skeleton variant="card" className="h-72" />
      </div>
    );
  }
  if (isError) {
    return <ErrorState inline onRetry={() => { mealsQ.refetch(); weightsQ.refetch(); sessionsQ.refetch(); }} />;
  }

  const calGoal = goalsQ.data?.dailyCalorieGoal ?? null;
  const proteinGoal = goalsQ.data?.dailyProteinGoal ?? null;
  const pct = (v: number, goal: number | null) => (goal ? Math.round((v / goal) * 100) : null);
  const kcalPct = averages && calGoal ? pct(averages.kcal, calGoal) : null;

  return (
    <div className="flex flex-col gap-5">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricTile
          icon="local_fire_department"
          label={o("kpiCalories")}
          color="var(--metric-kcal)"
          value={averages ? fmt.number(averages.kcal, 0) : "—"}
          unit={averages ? (calGoal ? `/ ${fmt.number(calGoal, 0)} kcal` : "kcal") : undefined}
          progress={averages && calGoal ? Math.min(1, averages.kcal / calGoal) : undefined}
          subline={averages ? (kcalPct != null ? o("percentOfGoal", { pct: kcalPct }) : o("loggedDays", { count: averages.loggedDays })) : o("nothingLogged7")}
        />
        <MetricTile
          icon="egg_alt"
          label={o("kpiProtein")}
          color="var(--metric-protein)"
          value={averages ? fmt.number(averages.protein, 0) : "—"}
          unit={averages ? (proteinGoal ? `/ ${fmt.number(proteinGoal, 0)} g` : "g") : undefined}
          progress={averages && proteinGoal ? Math.min(1, averages.protein / proteinGoal) : undefined}
          subline={averages ? o("loggedDays", { count: averages.loggedDays }) : o("nothingLogged7")}
        />
        <MetricTile
          icon="fitness_center"
          label={o("kpiWorkouts")}
          color="var(--primary)"
          value={week.scheduled > 0 ? `${week.done} / ${week.scheduled}` : "—"}
          progress={week.scheduled > 0 ? week.done / week.scheduled : undefined}
          subline={week.scheduled === 0 ? o("nothingScheduledWeek") : week.missedDates.length > 0 ? o("missedThisWeek", { count: week.missedDates.length }) : week.done === week.scheduled ? o("allDone") : o("scheduledThisWeek", { count: week.scheduled })}
        />
        <MetricTile
          icon="monitor_weight"
          label={o("kpiWeight")}
          color="var(--metric-weight)"
          value={weight ? fmt.number(weight.latestKg, 1) : "—"}
          unit={weight ? "kg" : undefined}
          delta={weight?.deltaKg != null ? <DeltaChip value={weight.deltaKg} unit="kg" size="small" /> : undefined}
          subline={weight ? (weight.deltaKg != null ? o("weightIn30") : o("weightSingle")) : o("noWeighIn")}
        />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,2fr)_minmax(0,1fr)] gap-5 items-start">
        <LoggingHeatmap weeks={heat} />
        <div className="flex flex-col gap-5">
          <UpcomingSchedule sessions={upcoming} clientId={clientId} />
          <ActivityFeed events={feed} />
        </div>
      </div>

      <Card variant="card" className="flex flex-col gap-3">
        <h3 style={{ fontSize: 18, fontWeight: 800 }}>{t("assignedPlans")}</h3>
        {!assignmentsQ.data || assignmentsQ.data.length === 0 ? (
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("noAssignedPlans")}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {assignmentsQ.data.map((a) => (
              <li key={a.id} className="flex items-center gap-3 p-3" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
                <span className="inline-flex items-center justify-center shrink-0" style={{ width: 38, height: 38, borderRadius: 12, background: "var(--card)" }}>
                  <Icon name={CONTENT_ICON[a.contentType]} size={20} fill={1} color="var(--role)" />
                </span>
                <span className="flex flex-col flex-1 min-w-0">
                  <span className="truncate" style={{ fontWeight: 700 }}>{sourceName(a.contentType, a.sourceId)}</span>
                  <span className="type-body-s" style={{ color: "var(--text-2)" }}>
                    {t(a.contentType === "TEMPLATE" ? "planTypeTemplate" : "planTypeRecipe")}
                  </span>
                </span>
                <span className="type-body-s tabular shrink-0" style={{ color: "var(--text-3)" }}>{fmt.shortDate(new Date(a.assignedAt))}</span>
                <UnassignButton
                  assignmentId={a.id}
                  clientId={clientId}
                  contentType={a.contentType}
                  sourceId={a.sourceId}
                  contentName={sourceName(a.contentType, a.sourceId)}
                />
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
