"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { Card, Drawer } from "@/components/ds";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { CardioSessionDetail } from "@/features/workouts/components/CardioSessionDetail";
import { SessionRow } from "@/features/workouts/components/SessionRow";
import { SessionSummary, sessionTitle, sessionWhenLabel } from "@/features/workouts/components/SessionSummary";
import { WeekHeader } from "@/features/workouts/components/WeekHeader";
import { recordsBySession, setFactsFromSessions } from "@/features/workouts/personalRecords";
import { groupSessionsByWeek } from "@/features/workouts/sessionGroups";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/i18n/format";
import { trainerApi } from "../api";
import { SessionCommentEditor } from "./SessionCommentEditor";

const PAGE_SIZE = 100;

interface ClientWorkoutsTabProps {
  clientId: number;
  /** Set when arriving from the Schedule tab's "jump to session" or a calendar deep link — opens that session once loaded. */
  focusSessionId?: number | null;
  onFocusHandled?: () => void;
}

/**
 * The client's workouts (W7-C): the W3 week-grouped history in read-only mode — the same rows with the 🏆 chips, no
 * delete, no "start" or "repeat" — and a click opens that session's summary in a drawer with the trainer's comment
 * editor (add, edit, delete) under the sets. Cardio sessions open their read-only detail. The newest 100 sessions are
 * loaded; records are judged against that history.
 */
export function ClientWorkoutsTab({ clientId, focusSessionId, onFocusHandled }: ClientWorkoutsTabProps) {
  const t = useTranslations("admin.clientDetail");
  const tw = useTranslations("workouts");
  const d = useTranslations("dashboard");
  const { locale } = useFormat();
  const [openId, setOpenId] = useState<number | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerClientData.sessions(clientId, 0, PAGE_SIZE),
    queryFn: () => trainerApi.clientWorkoutSessions(clientId, 0, PAGE_SIZE),
  });

  const sessions = useMemo(
    () => (data?.content ?? []).slice().sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime()),
    [data],
  );
  const weeks = useMemo(() => groupSessionsByWeek(sessions, new Date()), [sessions]);
  const records = useMemo(() => recordsBySession(setFactsFromSessions(sessions)), [sessions]);

  // A deep link opens its session once, as soon as the list has it.
  const handled = useRef<number | null>(null);
  useEffect(() => {
    if (focusSessionId == null || handled.current === focusSessionId) return;
    if (!sessions.some((s) => s.id === focusSessionId)) return;
    handled.current = focusSessionId;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-shot deep link, guarded by the ref
    setOpenId(focusSessionId);
    onFocusHandled?.();
  }, [focusSessionId, sessions, onFocusHandled]);

  if (isLoading) return <Skeleton variant="table" />;
  if (isError) return <ErrorState onRetry={refetch} />;
  if (sessions.length === 0) return <EmptyState icon="fitness_center" title={t("noSessions")} />;

  const open = openId != null ? sessions.find((s) => s.id === openId) ?? null : null;

  return (
    <div className="flex flex-col gap-5">
      {weeks.map((week) => (
        <section key={week.weekStart.getTime()} className="flex flex-col gap-2">
          <WeekHeader week={week} />
          <Card className="!p-0 overflow-hidden">
            <ul className="divide-y" style={{ borderColor: "var(--hairline)" }}>
              {week.sessions.map((s) => (
                <li key={s.id} style={{ borderColor: "var(--hairline)" }}>
                  <SessionRow session={s} records={records.get(s.id)} selected={s.id === openId} readOnly onOpen={() => setOpenId(s.id)} />
                </li>
              ))}
            </ul>
          </Card>
        </section>
      ))}

      {open && (
        <Drawer
          open
          onClose={() => setOpenId(null)}
          width={480}
          overline={sessionWhenLabel(open, locale)}
          title={open.sessionKind === "CARDIO" ? tw(`activityTypes.${open.activityType ?? "OTHER_CARDIO"}`) : sessionTitle(open, d("workoutFallback"))}
        >
          {open.sessionKind === "CARDIO" ? (
            <div className="flex flex-col gap-5">
              <CardioSessionDetail session={open} history={sessions} />
              <SessionCommentEditor clientId={clientId} session={open} />
            </div>
          ) : (
            <SessionSummary session={open} history={sessions} bare readOnly after={<SessionCommentEditor clientId={clientId} session={open} />} />
          )}
        </Drawer>
      )}
    </div>
  );
}
