"use client";

import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { templateApi, workoutSessionApi } from "@/features/workouts/api";
import { LiveSession } from "@/features/workouts/components/live/LiveSession";
import { queryKeys } from "@/lib/api/queryKeys";

/**
 * The live workout logger (W3.6, W3-B) — a focus-mode route: `routeChrome` gives `/workouts/session/*` no
 * sidebar, top bar or bottom nav. The session comes from the same list the workouts page uses (the API has
 * no single-session read), so a reload lands straight back in the workout, with the clock derived from `startedAt`.
 */
export default function LiveSessionPage() {
  const t = useTranslations("workouts");
  const router = useRouter();
  const id = Number(useParams<{ id: string }>().id);
  const leave = () => router.replace("/workouts");

  const { data, isLoading, isError, refetch } = useQuery({ queryKey: queryKeys.workoutSessions.all(), queryFn: workoutSessionApi.list });
  const { data: templates, isLoading: templatesLoading } = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });

  if (isLoading || templatesLoading) {
    return (
      <div className="p-6">
        <Skeleton variant="table" />
      </div>
    );
  }
  if (isError || !data) {
    return (
      <div className="p-6">
        <ErrorState onRetry={refetch} />
      </div>
    );
  }

  const session = data.find((s) => s.id === id);
  // Cardio has no set logger (docs/cardio/58 D-W.2) — it is read on the workouts page, so a stray link goes there.
  if (!session || session.sessionKind !== "STRENGTH") {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center">
        <p className="type-body">{t("liveNotFound")}</p>
        <Button onClick={leave}>{t("backToHistory")}</Button>
      </div>
    );
  }

  const template = session.templateId != null ? templates?.find((x) => x.id === session.templateId) : undefined;
  const plannedSets = template?.exercises.reduce((sum, e) => sum + e.targetSets, 0) ?? 0;
  const history = data.slice().sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());

  return <LiveSession key={session.id} session={session} history={history} plannedSets={plannedSets} onLeave={leave} />;
}
