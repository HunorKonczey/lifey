"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button, Card, ConfirmModal, Icon, IconButton } from "@/components/ds";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { currentWeekNumber, weeksBetween } from "../program";
import { ScheduleProgress } from "./ScheduleProgress";
import type { ProgramAssignmentSummaryResponse } from "../types";

interface ProgramListProps {
  clientId: number;
  assignments: ProgramAssignmentSummaryResponse[];
  onOpenAssignDrawer: () => void;
}

/** The client's multi-week programs (W7-C): "4 hetes alapozó · 3. hét", adherence, and cancel behind a confirmation. */
export function ProgramList({ clientId, assignments, onOpenAssignDrawer }: ProgramListProps) {
  const t = useTranslations("admin.programs");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [confirmingId, setConfirmingId] = useState<number | null>(null);

  const cancelMutation = useMutation({
    mutationFn: (assignmentId: number) => trainerApi.cancelProgramAssignment(assignmentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerProgramAssignments.forClient(clientId) });
      show(t("assignmentCancelled"), "success");
    },
    onError: () => show(t("assignmentCancelFailed"), "error"),
  });

  const active = assignments.filter((a) => a.cancelledAt == null);
  if (active.length === 0) return null;

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-3">
        <h3 style={{ fontSize: 18, fontWeight: 800 }}>{t("programsSectionTitle")}</h3>
        <Button variant="secondary" onClick={onOpenAssignDrawer} data-testid="assign-program-cta">
          <Icon name="add" size={18} />
          {t("assignAction")}
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {active.map((assignment) => {
          const totalWeeks = weeksBetween(assignment.startDate, assignment.endDate);
          const currentWeek = currentWeekNumber(assignment.startDate, totalWeeks);
          return (
            <Card key={assignment.id} variant="card" className="flex flex-col gap-4" data-testid="program-assignment-card">
              <div className="flex items-center gap-3.5">
                <span className="inline-flex items-center justify-center shrink-0" style={{ width: 44, height: 44, borderRadius: 14, background: "var(--nested)" }}>
                  <Icon name="event_repeat" size={22} fill={1} color="var(--role)" />
                </span>
                <div className="flex-1 min-w-0">
                  <p className="truncate" style={{ fontSize: 16, fontWeight: 800 }}>{assignment.programName}</p>
                  <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("weekProgress", { current: currentWeek, total: totalWeeks })}</p>
                </div>
                <IconButton icon="event_busy" label={t("cancelAssignment")} onClick={() => setConfirmingId(assignment.id)} />
              </div>
              <ScheduleProgress done={assignment.doneCount} missed={assignment.missedCount} remaining={assignment.remainingCount} />
            </Card>
          );
        })}
      </div>

      <ConfirmModal
        open={confirmingId != null}
        onClose={() => setConfirmingId(null)}
        onConfirm={() => {
          if (confirmingId != null) cancelMutation.mutate(confirmingId);
          setConfirmingId(null);
        }}
        icon="event_busy"
        title={t("cancelAssignmentConfirmTitle")}
        body={t("cancelAssignmentConfirmBody")}
        cancelLabel={t("cancelAssignmentKeep")}
        confirmLabel={t("cancelAssignmentConfirm")}
      />
    </div>
  );
}
