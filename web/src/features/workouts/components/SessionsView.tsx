"use client";

import { useEffect, useRef, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { workoutSessionApi, templateApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { CardioSessionDetail } from "./CardioSessionDetail";
import { RecommendedWorkoutCard } from "./RecommendedWorkoutCard";
import { SessionRow } from "./SessionRow";
import { TemplatePicker } from "./TemplatePicker";
import { WeekHeader } from "./WeekHeader";
import { SessionSummary, sessionTitle, sessionWhenLabel } from "./SessionSummary";
import { Card } from "@/components/ds";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useFormat } from "@/lib/i18n/format";
import type { WorkoutSessionResponse } from "../types";
import { groupSessionsByWeek } from "../sessionGroups";
import { recordsBySession, setFactsFromSessions } from "../personalRecords";
import { recommendedTemplate } from "../recommendation";
import { matchesTypeFilter, type SessionTypeFilter } from "../workoutsTab";

export function SessionsView({
  typeFilter = "all",
  starting = false,
  onStartingChange,
  autoStartTemplateId,
  autoOpenSessionId,
  onAutoStartHandled,
}: {
  // The page's type chips (W3.1) and its "Edzés indítása" / `N` state — the start dialog is shown here.
  typeFilter?: SessionTypeFilter;
  starting?: boolean;
  onStartingChange?: (starting: boolean) => void;
  // Set when navigated here from the dashboard's recommended-workout card —
  // starts this template's session automatically once templates are loaded.
  autoStartTemplateId?: number | null;
  // Set when navigated here from a dashboard recent-workouts row — opens that
  // session once (until W3's own session summary route exists).
  autoOpenSessionId?: number | null;
  onAutoStartHandled?: () => void;
} = {}) {
  const t = useTranslations("workouts");
  const d = useTranslations("dashboard");
  const { locale } = useFormat();
  const router = useRouter();
  const logSession = (id: number) => router.push(`/workouts/session/${id}`);
  const sidePanel = useMediaQuery("(min-width: 1280px)");
  const queryClient = useQueryClient();
  const { show } = useToast();
  // `activeId` is the cardio detail (the set logger is its own focus-mode route, W3.6); `selectedId` the closed-session summary beside (or over) the list.
  const [activeId, setActiveId] = useState<number | null>(null);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const setStarting = (value: boolean) => onStartingChange?.(value);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.workoutSessions.all(),
    queryFn: workoutSessionApi.list,
  });

  const { data: templates } = useQuery({
    queryKey: queryKeys.workoutTemplates.all(),
    queryFn: templateApi.list,
  });

  const startMutation = useMutation({
    mutationFn: ({ exerciseIds, templateId }: { exerciseIds: number[]; templateId?: number | null }) =>
      workoutSessionApi.create({
        startedAt: new Date().toISOString(),
        finishedAt: null,
        exerciseIds,
        sets: [],
        activeCalories: null,
        averageHeartRate: null,
        healthWorkoutId: null,
        templateId,
      }),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutSessions.all() });
      setStarting(false);
      logSession(created.id);
      show(t("workoutStarted"), "success");
    },
    onError: () => show(t("startFailed"), "error"),
  });

  const sessions = (data ?? []).slice().sort(
    (a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime(),
  );

  const visible = sessions.filter((s) => matchesTypeFilter(s.sessionKind, typeFilter));

  const active = activeId != null ? sessions.find((s) => s.id === activeId) ?? null : null;
  const selected = selectedId != null ? sessions.find((s) => s.id === selectedId) ?? null : null;
  // A finished strength session opens as its summary; a running one goes back to its logger, cardio to its detail.
  const openSession = (s: WorkoutSessionResponse) => {
    if (s.sessionKind === "STRENGTH" && s.finishedAt) setSelectedId(s.id);
    else if (s.sessionKind === "STRENGTH") logSession(s.id);
    else setActiveId(s.id);
  };
  const weeks = groupSessionsByWeek(visible, new Date());
  // Records come from the whole history, not the filtered list — a filter must not change what counts as a PR.
  const records = recordsBySession(setFactsFromSessions(sessions));
  const recommended = recommendedTemplate(sessions, templates ?? []);

  // Auto-start the template the dashboard's recommended-workout card pointed
  // at, once templates have loaded — runs at most once per mount.
  const autoStartedRef = useRef(false);
  useEffect(() => {
    if (autoStartedRef.current || !autoStartTemplateId || !templates || active) return;
    const tpl = templates.find((t) => t.id === autoStartTemplateId);
    if (!tpl) return;
    autoStartedRef.current = true;
    startMutation.mutate({ exerciseIds: tpl.exercises.map((e) => e.exerciseId), templateId: tpl.id });
    onAutoStartHandled?.();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoStartTemplateId, templates, active]);

  const autoOpenedRef = useRef(false);
  useEffect(() => {
    if (autoOpenedRef.current || !autoOpenSessionId || !data) return;
    const target = data.find((s) => s.id === autoOpenSessionId);
    if (!target) return;
    autoOpenedRef.current = true;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-shot deep link, guarded by the ref
    openSession(target);
    onAutoStartHandled?.();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoOpenSessionId, data]);

  // ─── Cardio detail mode ───
  if (active) {
    return (
      <div>
        <button onClick={() => setActiveId(null)}
          className="flex items-center gap-1 mb-4 text-sm font-semibold" style={{ color: "var(--text-2)" }}>
          <span aria-hidden="true" className="material-symbols-rounded text-lg">arrow_back</span> {t("backToHistory")}
        </button>
        {/* Cardio never opens the set-logger — the web reads/filters/statisticizes
            cardio but never edits it (docs/cardio/58-cardio-web-plan.md D-W.2). */}
        <CardioSessionDetail session={active} history={sessions} />
      </div>
    );
  }

  const summary = selected && (
    <SessionSummary
      session={selected}
      history={sessions}
      bare={!sidePanel}
      starting={startMutation.isPending}
      onRepeat={() =>
        startMutation.mutate({ exerciseIds: selected.exercises.map((e) => e.exerciseId), templateId: selected.templateId })
      }
      onEdit={() => logSession(selected.id)}
      onDeleted={() => setSelectedId(null)}
    />
  );

  return (
    <div className={sidePanel ? "grid items-start gap-6" : undefined} style={sidePanel ? { gridTemplateColumns: "minmax(0, 1fr) 440px" } : undefined}>
    <div className="flex min-w-0 flex-col gap-4">
      {recommended && (
        <RecommendedWorkoutCard
          template={recommended}
          starting={startMutation.isPending}
          onStart={() =>
            startMutation.mutate({
              exerciseIds: recommended.exercises.map((e) => e.exerciseId),
              templateId: recommended.id,
            })
          }
        />
      )}

      <p className="text-sm font-bold">{t("history")}</p>

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : sessions.length === 0 ? (
        <EmptyState icon="exercise" title={t("noWorkoutsYet")} body={t("startToBegin")} />
      ) : visible.length === 0 ? (
        <EmptyState icon="exercise" title={t("noMatches")} />
      ) : (
        <div className="flex flex-col gap-5">
          {weeks.map((week) => (
            <section key={week.weekStart.getTime()} className="flex flex-col gap-2">
              <WeekHeader week={week} />
              <Card className="!p-0 overflow-hidden">
                <ul className="divide-y" style={{ borderColor: "var(--hairline)" }}>
                  {week.sessions.map((s) => (
                    <li key={s.id} style={{ borderColor: "var(--hairline)" }}>
                      <SessionRow session={s} records={records.get(s.id)} selected={s.id === selectedId} onOpen={() => openSession(s)} />
                    </li>
                  ))}
                </ul>
              </Card>
            </section>
          ))}
        </div>
      )}

      <TemplatePicker
        open={starting}
        onClose={() => setStarting(false)}
        templates={templates ?? []}
        sessions={sessions}
        recommendedId={recommended?.id ?? null}
        starting={startMutation.isPending}
        onStart={(tpl) =>
          startMutation.mutate(tpl ? { exerciseIds: tpl.exercises.map((e) => e.exerciseId), templateId: tpl.id } : { exerciseIds: [] })
        }
      />
    </div>

    {sidePanel && (
      <aside className="sticky top-4" aria-label={t("summaryAria")}>
        <Card>
          {summary ?? (
            <p className="type-body-s py-10 text-center" style={{ color: "var(--text-3)" }}>
              {t("summaryPlaceholder")}
            </p>
          )}
        </Card>
      </aside>
    )}
    {!sidePanel && selected && (
      <Drawer
        open
        onClose={() => setSelectedId(null)}
        width={480}
        overline={sessionWhenLabel(selected, locale)}
        title={sessionTitle(selected, d("workoutFallback"))}
      >
        {summary}
      </Drawer>
    )}
    </div>
  );
}
