"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { addMonths, format } from "date-fns";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { ScheduleList } from "./ScheduleList";
import { ScheduleTimeline } from "./ScheduleTimeline";
import { ProgramList } from "./ProgramList";
import { AssignProgramDrawer } from "./AssignProgramDrawer";
import { nameFor } from "./ClientAvatar";
import { Button, Icon } from "@/components/ds";

interface ClientScheduleTabProps {
  clientId: number;
  clientEmail: string;
  /** Profile name when known; falls back to one derived from the email. */
  clientName?: string;
  onOpenDrawer: () => void;
  onViewSession: (sessionId: number) => void;
}

export function ClientScheduleTab({ clientId, clientEmail, clientName, onOpenDrawer, onViewSession }: ClientScheduleTabProps) {
  const t = useTranslations("admin.schedule");
  const tPrograms = useTranslations("admin.programs");
  const [historyOpen, setHistoryOpen] = useState(false);
  const [assignDrawerOpen, setAssignDrawerOpen] = useState(false);

  const { from, to } = useMemo(() => {
    const today = new Date();
    return {
      from: format(historyOpen ? addMonths(today, -3) : today, "yyyy-MM-dd"),
      to: format(addMonths(today, 3), "yyyy-MM-dd"),
    };
  }, [historyOpen]);

  const schedulesQ = useQuery({
    queryKey: queryKeys.trainerSchedules.forClient(clientId),
    queryFn: () => trainerApi.schedulesForClient(clientId),
  });
  const occurrencesQ = useQuery({
    queryKey: queryKeys.trainerSchedules.occurrences(clientId, from, to),
    queryFn: () => trainerApi.scheduledSessions(clientId, from, to),
  });
  const programAssignmentsQ = useQuery({
    queryKey: queryKeys.trainerProgramAssignments.forClient(clientId),
    queryFn: () => trainerApi.programAssignmentsForClient(clientId),
  });

  if (schedulesQ.isLoading || occurrencesQ.isLoading || programAssignmentsQ.isLoading) {
    return (
      <div className="flex flex-col gap-3.5">
        <Skeleton variant="card" className="h-32" />
        <Skeleton variant="table" />
      </div>
    );
  }
  if (schedulesQ.isError || occurrencesQ.isError || programAssignmentsQ.isError) {
    return (
      <ErrorState
        onRetry={() => { schedulesQ.refetch(); occurrencesQ.refetch(); programAssignmentsQ.refetch(); }}
      />
    );
  }

  const schedules = schedulesQ.data ?? [];
  const occurrences = occurrencesQ.data ?? [];
  const programAssignments = programAssignmentsQ.data ?? [];
  const programNamesById = Object.fromEntries(programAssignments.map((a) => [a.id, a.programName]));
  const isEmpty = schedules.length === 0 && occurrences.length === 0 && programAssignments.length === 0;

  return (
    <div className="flex flex-col gap-5">
      {isEmpty ? (
        <EmptyState
          icon="calendar_month"
          title={t("emptyTitle")}
          action={
            <div className="flex flex-wrap items-center justify-center gap-2.5">
              <Button onClick={onOpenDrawer}>
                <Icon name="add" size={18} />
                {t("scheduleWorkout")}
              </Button>
              <Button variant="secondary" onClick={() => setAssignDrawerOpen(true)}>
                <Icon name="event_repeat" size={18} />
                {tPrograms("assignAction")}
              </Button>
            </div>
          }
        />
      ) : (
        <>
          <ProgramList
            clientId={clientId}
            assignments={programAssignments}
            onOpenAssignDrawer={() => setAssignDrawerOpen(true)}
          />
          <ScheduleList clientId={clientId} schedules={schedules} />
          <ScheduleTimeline
            clientId={clientId}
            occurrences={occurrences}
            onViewSession={onViewSession}
            programNamesById={programNamesById}
          />
          {!historyOpen && (
            <Button variant="ghost" className="self-center" onClick={() => setHistoryOpen(true)}>
              {t("showHistory")}
            </Button>
          )}
        </>
      )}

      {assignDrawerOpen && (
        <AssignProgramDrawer
          clientId={clientId}
          clientName={clientName ?? nameFor(clientEmail)}
          onClose={() => setAssignDrawerOpen(false)}
        />
      )}
    </div>
  );
}
