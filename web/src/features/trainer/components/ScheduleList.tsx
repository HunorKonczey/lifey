"use client";

import { useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Card, ConfirmModal, Icon, Menu } from "@/components/ds";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { RecurrenceLabel } from "./RecurrenceLabel";
import { ScheduleProgress } from "./ScheduleProgress";
import type { ScheduleSummaryResponse } from "../types";

interface ScheduleListProps {
  clientId: number;
  schedules: ScheduleSummaryResponse[];
}

/** The client's recurring schedules as cards (W7-C): template, how it repeats, done / missed / remaining, "⋯" → cancel the series. */
export function ScheduleList({ clientId, schedules }: ScheduleListProps) {
  const t = useTranslations("admin.schedule");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [confirmingId, setConfirmingId] = useState<number | null>(null);

  const cancelMutation = useMutation({
    mutationFn: (scheduleId: number) => trainerApi.cancelSchedule(scheduleId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerSchedules.forClient(clientId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerTemplates.usage() });
      show(t("scheduleCancelled"), "success");
    },
    onError: () => show(t("scheduleCancelFailed"), "error"),
  });

  if (schedules.length === 0) return null;

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {schedules.map((schedule) => (
        <Card key={schedule.id} variant="card" className="flex flex-col gap-4">
          <div className="flex items-center gap-3.5">
            <span className="inline-flex items-center justify-center shrink-0" style={{ width: 44, height: 44, borderRadius: 14, background: "var(--nested)" }}>
              <Icon name="fitness_center" size={22} fill={1} color="var(--role)" />
            </span>
            <div className="flex-1 min-w-0">
              <p className="truncate" style={{ fontSize: 16, fontWeight: 800 }}>{schedule.templateName}</p>
              <p className="type-body-s" style={{ color: "var(--text-2)" }}>
                <RecurrenceLabel
                  recurrence={schedule.recurrence}
                  daysOfWeek={schedule.daysOfWeek}
                  timeOfDay={schedule.timeOfDay}
                  startDate={schedule.startDate}
                  endDate={schedule.endDate}
                />
              </p>
            </div>
            <SeriesMenu label={t("scheduleMenu")} cancelLabel={t("cancelSeries")} onCancel={() => setConfirmingId(schedule.id)} />
          </div>
          <ScheduleProgress done={schedule.doneCount} missed={schedule.missedCount} remaining={schedule.remainingCount} />
        </Card>
      ))}

      <ConfirmModal
        open={confirmingId != null}
        onClose={() => setConfirmingId(null)}
        onConfirm={() => {
          const id = confirmingId;
          setConfirmingId(null);
          if (id != null) cancelMutation.mutate(id);
        }}
        icon="event_busy"
        title={t("cancelSeriesConfirmTitle")}
        body={t("cancelSeriesConfirmBody")}
        cancelLabel={t("keepSeries")}
        confirmLabel={t("cancelSeriesConfirm")}
      />
    </div>
  );
}

/** The card's "⋯": owns its anchor and open state, so the menu opens under the button it came from. */
function SeriesMenu({ label, cancelLabel, onCancel }: { label: string; cancelLabel: string; onCancel: () => void }) {
  const ref = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        ref={ref}
        type="button"
        onClick={() => setOpen(true)}
        aria-label={label}
        aria-haspopup="menu"
        aria-expanded={open}
        className="lifey-button inline-flex items-center justify-center shrink-0"
        style={{ width: 32, height: 32, borderRadius: "var(--r-control)", color: "var(--text-2)" }}
      >
        <Icon name="more_horiz" size={22} />
      </button>
      <Menu open={open} onClose={() => setOpen(false)} anchorRef={ref} items={[{ label: cancelLabel, icon: "event_busy", destructive: true, onSelect: onCancel }]} />
    </>
  );
}
