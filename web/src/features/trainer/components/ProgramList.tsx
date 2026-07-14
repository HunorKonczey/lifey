"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { currentWeekNumber, weeksBetween } from "../program";
import type { ProgramAssignmentSummaryResponse } from "../types";

interface ProgramListProps {
  clientId: number;
  assignments: ProgramAssignmentSummaryResponse[];
  onOpenAssignDrawer: () => void;
}

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
      <div className="flex items-center justify-between">
        <p className="text-sm font-extrabold" style={{ color: "var(--on-surface)" }}>
          {t("programsSectionTitle")}
        </p>
        <button
          onClick={onOpenAssignDrawer}
          data-testid="assign-program-cta"
          className="flex items-center gap-1 text-[12.5px] font-bold"
          style={{ color: "var(--tertiary)" }}
        >
          <span className="material-symbols-rounded text-base">add</span>
          {t("assignAction")}
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
        {active.map((assignment) => {
          const total = assignment.doneCount + assignment.missedCount + assignment.remainingCount;
          const donePct = total > 0 ? (assignment.doneCount / total) * 100 : 0;
          const missedPct = total > 0 ? (assignment.missedCount / total) * 100 : 0;
          const totalWeeks = weeksBetween(assignment.startDate, assignment.endDate);
          const currentWeek = currentWeekNumber(assignment.startDate, totalWeeks);

          return (
            <div
              key={assignment.id}
              data-testid="program-assignment-card"
              className="relative rounded-[var(--r-card)] p-5"
              style={{ background: "var(--surface)" }}
            >
              <div className="flex items-center gap-3.5">
                <span
                  className="w-11 h-11 rounded-2xl flex items-center justify-center shrink-0"
                  style={{ background: "var(--surface-high)", color: "var(--tertiary)" }}
                >
                  <span className="material-symbols-rounded text-xl" style={{ fontVariationSettings: "'FILL' 1" }}>
                    event_repeat
                  </span>
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-[15px] font-extrabold truncate" style={{ color: "var(--on-surface)" }}>
                    {assignment.programName}
                  </p>
                  <p className="text-xs mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                    {t("weekProgress", { current: currentWeek, total: totalWeeks })}
                  </p>
                </div>
                <button
                  onClick={() => setConfirmingId(assignment.id)}
                  className="w-8.5 h-8.5 rounded-[11px] flex items-center justify-center shrink-0"
                  style={{ background: "var(--surface-high)", color: "var(--error)" }}
                  aria-label={t("cancelAssignment")}
                >
                  <span className="material-symbols-rounded text-lg">event_busy</span>
                </button>
              </div>

              <div className="flex items-center gap-3.5 mt-3.5 flex-wrap">
                <span className="flex items-center gap-1.5 text-xs font-bold" style={{ color: "var(--tertiary)" }}>
                  <span className="material-symbols-rounded text-base" style={{ fontVariationSettings: "'FILL' 1" }}>check_circle</span>
                  {t("doneCount", { count: assignment.doneCount })}
                </span>
                {assignment.missedCount > 0 && (
                  <span className="flex items-center gap-1.5 text-xs font-bold" style={{ color: "var(--error)" }}>
                    <span className="material-symbols-rounded text-base">warning</span>
                    {t("missedCount", { count: assignment.missedCount })}
                  </span>
                )}
                <span className="flex items-center gap-1.5 text-xs font-bold" style={{ color: "var(--on-surface-variant)" }}>
                  <span className="material-symbols-rounded text-base">schedule</span>
                  {t("remainingCount", { count: assignment.remainingCount })}
                </span>
              </div>

              <div className="h-1.5 rounded-full mt-3 overflow-hidden flex" style={{ background: "var(--surface-container)" }}>
                <div style={{ width: `${donePct}%`, background: "var(--tertiary)" }} />
                <div style={{ width: `${missedPct}%`, background: "var(--error)", opacity: 0.7 }} />
              </div>
            </div>
          );
        })}
      </div>

      <ConfirmDialog
        open={confirmingId != null}
        title={t("cancelAssignmentConfirmTitle")}
        body={t("cancelAssignmentConfirmBody")}
        confirmLabel={t("cancelAssignmentConfirm")}
        confirming={cancelMutation.isPending}
        onConfirm={() => {
          if (confirmingId != null) cancelMutation.mutate(confirmingId);
          setConfirmingId(null);
        }}
        onCancel={() => setConfirmingId(null)}
      />
    </div>
  );
}
