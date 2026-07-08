"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { RecurrenceLabel } from "./RecurrenceLabel";
import type { ScheduleSummaryResponse } from "../types";

interface ScheduleListProps {
  clientId: number;
  schedules: ScheduleSummaryResponse[];
}

export function ScheduleList({ clientId, schedules }: ScheduleListProps) {
  const t = useTranslations("admin.schedule");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [menuOpenId, setMenuOpenId] = useState<number | null>(null);
  const [confirmingId, setConfirmingId] = useState<number | null>(null);

  useEffect(() => {
    if (menuOpenId == null) return;
    function handleClick(e: MouseEvent) {
      if (!(e.target as HTMLElement).closest("[data-schedule-menu-root]")) setMenuOpenId(null);
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [menuOpenId]);

  const cancelMutation = useMutation({
    mutationFn: (scheduleId: number) => trainerApi.cancelSchedule(scheduleId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerSchedules.forClient(clientId) });
      show(t("scheduleCancelled"), "success");
    },
    onError: () => show(t("scheduleCancelFailed"), "error"),
  });

  if (schedules.length === 0) return null;

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
      {schedules.map((schedule) => {
        const total = schedule.doneCount + schedule.missedCount + schedule.remainingCount;
        const donePct = total > 0 ? (schedule.doneCount / total) * 100 : 0;
        const missedPct = total > 0 ? (schedule.missedCount / total) * 100 : 0;

        return (
          <div
            key={schedule.id}
            data-schedule-menu-root={menuOpenId === schedule.id ? true : undefined}
            className="relative rounded-[var(--r-card)] p-5"
            style={{ background: "var(--surface)" }}
          >
            <div className="flex items-center gap-3.5">
              <span
                className="w-11 h-11 rounded-2xl flex items-center justify-center shrink-0"
                style={{ background: "var(--surface-high)", color: "var(--tertiary)" }}
              >
                <span className="material-symbols-rounded text-xl" style={{ fontVariationSettings: "'FILL' 1" }}>
                  fitness_center
                </span>
              </span>
              <div className="flex-1 min-w-0">
                <p className="text-[15px] font-extrabold truncate" style={{ color: "var(--on-surface)" }}>
                  {schedule.templateName}
                </p>
                <p className="text-xs mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                  <RecurrenceLabel
                    recurrence={schedule.recurrence}
                    daysOfWeek={schedule.daysOfWeek}
                    timeOfDay={schedule.timeOfDay}
                    startDate={schedule.startDate}
                    endDate={schedule.endDate}
                  />
                </p>
              </div>
              <button
                onClick={() => setMenuOpenId(menuOpenId === schedule.id ? null : schedule.id)}
                className="w-8.5 h-8.5 rounded-[11px] flex items-center justify-center shrink-0"
                style={{ background: "var(--surface-high)", color: "var(--on-surface)" }}
                aria-label={t("scheduleMenu")}
              >
                <span className="material-symbols-rounded text-lg">more_horiz</span>
              </button>
            </div>

            <div className="flex items-center gap-3.5 mt-3.5 flex-wrap">
              <span className="flex items-center gap-1.5 text-xs font-bold" style={{ color: "var(--tertiary)" }}>
                <span className="material-symbols-rounded text-base" style={{ fontVariationSettings: "'FILL' 1" }}>check_circle</span>
                {t("doneCount", { count: schedule.doneCount })}
              </span>
              {schedule.missedCount > 0 && (
                <span className="flex items-center gap-1.5 text-xs font-bold" style={{ color: "var(--error)" }}>
                  <span className="material-symbols-rounded text-base">warning</span>
                  {t("missedCount", { count: schedule.missedCount })}
                </span>
              )}
              <span className="flex items-center gap-1.5 text-xs font-bold" style={{ color: "var(--on-surface-variant)" }}>
                <span className="material-symbols-rounded text-base">schedule</span>
                {t("remainingCount", { count: schedule.remainingCount })}
              </span>
            </div>

            <div className="h-1.5 rounded-full mt-3 overflow-hidden flex" style={{ background: "var(--surface-container)" }}>
              <div style={{ width: `${donePct}%`, background: "var(--tertiary)" }} />
              <div style={{ width: `${missedPct}%`, background: "var(--error)", opacity: 0.7 }} />
            </div>

            {menuOpenId === schedule.id && (
              <div
                className="absolute top-14 right-4 w-56 rounded-2xl p-1.5 z-10"
                style={{ background: "var(--surface-high)", boxShadow: "0 18px 44px rgba(0,0,0,.35)" }}
              >
                <button
                  onClick={() => {
                    setMenuOpenId(null);
                    setConfirmingId(schedule.id);
                  }}
                  className="w-full flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-left text-[13px] font-bold"
                  style={{ color: "var(--error)" }}
                >
                  <span className="material-symbols-rounded text-lg">event_busy</span>
                  {t("cancelSeries")}
                </button>
              </div>
            )}

            {confirmingId === schedule.id && (
              <div
                className="fixed inset-0 z-30 flex items-center justify-center p-4"
                style={{ background: "rgba(8,9,6,.6)" }}
                onClick={() => setConfirmingId(null)}
              >
                <div
                  onClick={(e) => e.stopPropagation()}
                  className="w-full max-w-sm rounded-[var(--r-lg)] p-6"
                  style={{ background: "var(--surface-container)", boxShadow: "0 18px 44px rgba(0,0,0,.4)" }}
                >
                  <p className="text-base font-extrabold mb-2" style={{ color: "var(--on-surface)" }}>
                    {t("cancelSeriesConfirmTitle")}
                  </p>
                  <p className="text-[12.5px] leading-relaxed mb-5" style={{ color: "var(--on-surface-variant)" }}>
                    {t("cancelSeriesConfirmBody")}
                  </p>
                  <div className="flex gap-2.5 justify-end">
                    <button
                      onClick={() => setConfirmingId(null)}
                      className="text-sm font-bold px-4 py-2.5"
                      style={{ color: "var(--on-surface-variant)" }}
                    >
                      {t("keepSeries")}
                    </button>
                    <button
                      onClick={() => {
                        setConfirmingId(null);
                        cancelMutation.mutate(schedule.id);
                      }}
                      disabled={cancelMutation.isPending}
                      className="rounded-xl px-4.5 py-2.5 text-sm font-extrabold disabled:opacity-60"
                      style={{ background: "var(--error)", color: "#161611" }}
                    >
                      {t("cancelSeriesConfirm")}
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
