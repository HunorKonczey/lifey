"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { differenceInCalendarWeeks, format, startOfWeek } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useLocale } from "@/lib/hooks/useLocale";
import { STATUS_STYLE } from "../scheduleStatus";
import type { ScheduledSessionResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;
const PAGE_SIZE = 15;

interface ScheduleTimelineProps {
  clientId: number;
  occurrences: ScheduledSessionResponse[];
  /* Jumps to the session's detail in the Workouts tab (DONE occurrences only). */
  onViewSession?: (sessionId: number) => void;
  /* Resolves a program-origin occurrence's programAssignmentId to its program name, for the badge. */
  programNamesById?: Record<number, string>;
}

export function ScheduleTimeline({ clientId, occurrences, onViewSession, programNamesById }: ScheduleTimelineProps) {
  const t = useTranslations("admin.schedule");
  const tc = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const [confirmingId, setConfirmingId] = useState<number | null>(null);
  const [page, setPage] = useState(0);

  const cancelMutation = useMutation({
    mutationFn: (sessionId: number) => trainerApi.cancelOccurrence(sessionId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerSchedules.forClient(clientId) });
      show(t("occurrenceCancelled"), "success");
    },
    onError: () => show(t("occurrenceCancelFailed"), "error"),
  });

  const groups = useMemo(() => {
    const currentWeekStart = startOfWeek(new Date(), { weekStartsOn: 1 });
    const byWeek = new Map<string, ScheduledSessionResponse[]>();
    for (const occ of occurrences) {
      const weekStart = startOfWeek(new Date(`${occ.scheduledFor}T00:00:00`), { weekStartsOn: 1 });
      const key = format(weekStart, "yyyy-MM-dd");
      if (!byWeek.has(key)) byWeek.set(key, []);
      byWeek.get(key)!.push(occ);
    }
    return [...byWeek.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, items]) => {
        const diff = differenceInCalendarWeeks(new Date(`${key}T00:00:00`), currentWeekStart, { weekStartsOn: 1 });
        const label =
          diff === 0 ? t("thisWeek")
          : diff === 1 ? t("nextWeek")
          : diff === -1 ? t("lastWeek")
          : diff > 1 ? t("weeksAhead", { count: diff })
          : t("weeksAgo", { count: -diff });
        items.sort((x, y) => {
          const dateCmp = x.scheduledFor.localeCompare(y.scheduledFor);
          if (dateCmp !== 0) return dateCmp;
          if (!x.scheduledTime && !y.scheduledTime) return 0;
          if (!x.scheduledTime) return 1;
          if (!y.scheduledTime) return -1;
          return x.scheduledTime.localeCompare(y.scheduledTime);
        });
        return { key, label, items };
      });
  }, [occurrences, t]);

  const totalCount = groups.reduce((sum, g) => sum + g.items.length, 0);
  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));

  // Reset to page 0 when the occurrence list changes (e.g. history toggled,
  // cancellation refetch) instead of an effect, per React's render-time
  // state-adjustment pattern (see DatePicker's viewDate resync).
  const [prevOccurrences, setPrevOccurrences] = useState(occurrences);
  let effectivePage = page;
  if (occurrences !== prevOccurrences) {
    setPrevOccurrences(occurrences);
    effectivePage = 0;
    if (page !== 0) setPage(0);
  }
  const safePage = Math.min(effectivePage, totalPages - 1);

  const pageGroups = useMemo(() => {
    const start = safePage * PAGE_SIZE;
    const end = start + PAGE_SIZE;
    let seen = 0;
    const result: typeof groups = [];
    for (const group of groups) {
      const groupStart = seen;
      const groupEnd = seen + group.items.length;
      seen = groupEnd;
      if (groupEnd <= start || groupStart >= end) continue;
      const sliceStart = Math.max(0, start - groupStart);
      const sliceEnd = Math.min(group.items.length, end - groupStart);
      result.push({ ...group, items: group.items.slice(sliceStart, sliceEnd) });
    }
    return result;
  }, [groups, safePage]);

  if (occurrences.length === 0) return null;

  return (
    <div className="rounded-[var(--r-card)] p-5" style={{ background: "var(--surface-container)" }}>
      <p className="text-base font-extrabold mb-3.5" style={{ color: "var(--on-surface)" }}>{t("timeline")}</p>
      <div className="flex flex-col gap-4">
        {pageGroups.map(({ key, label, items }) => (
          <div key={key}>
            <p className="text-[11px] font-bold tracking-wider uppercase mb-2" style={{ color: "var(--on-surface-variant)" }}>
              {label}
            </p>
            <div className="flex flex-col gap-1.5">
              {items.map((occ) => {
                const style = STATUS_STYLE[occ.status];
                const cancelled = occ.status === "CANCELLED";
                const clickable = occ.status === "DONE" && !!onViewSession;
                const Row = clickable ? "button" : "div";
                return (
                  <Row
                    key={occ.sessionId}
                    onClick={clickable ? () => onViewSession!(occ.sessionId) : undefined}
                    className="rounded-2xl px-3.5 py-3 flex items-center gap-3.5 w-full text-left"
                    style={{ background: "var(--surface)", opacity: cancelled ? 0.5 : 1 }}
                  >
                    <span className="text-xs tabular w-20 shrink-0" style={{ color: "var(--on-surface-variant)" }}>
                      {format(new Date(`${occ.scheduledFor}T00:00:00`), "EEE, MMM d.", { locale: dateLocale })}
                      {occ.scheduledTime && ` · ${occ.scheduledTime.slice(0, 5)}`}
                    </span>
                    <span className="flex-1 min-w-0">
                      <span
                        className="block text-[13.5px] font-bold truncate"
                        style={{ color: "var(--on-surface)", textDecoration: cancelled ? "line-through" : "none" }}
                      >
                        {occ.templateName ?? t("unnamedTemplate")}
                      </span>
                      {occ.programAssignmentId != null && programNamesById?.[occ.programAssignmentId] && (
                        <span className="flex items-center gap-1 text-[10.5px] mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                          <span className="material-symbols-rounded text-xs">event_repeat</span>
                          {programNamesById[occ.programAssignmentId]}
                        </span>
                      )}
                    </span>
                    <span
                      className="flex items-center gap-1.5 rounded-full text-[11px] font-extrabold px-2.5 py-1 shrink-0"
                      style={{ background: style.bg, color: style.color, border: style.bg === "transparent" ? "1px solid var(--outline)" : "none" }}
                    >
                      <span className="material-symbols-rounded text-sm" style={{ fontVariationSettings: style.fill ? "'FILL' 1" : "'FILL' 0" }}>
                        {style.icon}
                      </span>
                      {t(`status.${occ.status}`)}
                    </span>
                    {clickable && (
                      <span className="material-symbols-rounded text-lg shrink-0" style={{ color: "var(--on-surface-variant)" }}>
                        chevron_right
                      </span>
                    )}
                    {occ.status === "UPCOMING" && (
                      <button
                        onClick={() => setConfirmingId(occ.sessionId)}
                        className="w-8 h-8 rounded-[10px] flex items-center justify-center shrink-0"
                        style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
                        aria-label={t("cancelOccurrence")}
                      >
                        <span className="material-symbols-rounded text-base">event_busy</span>
                      </button>
                    )}
                  </Row>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm" style={{ color: "var(--on-surface-variant)" }}>
          <span className="tabular text-xs">
            {tc("rangeOf", {
              from: safePage * PAGE_SIZE + 1,
              to: Math.min(safePage * PAGE_SIZE + PAGE_SIZE, totalCount),
              total: totalCount,
            })}
          </span>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              disabled={safePage === 0}
              className="p-1 rounded-[var(--r-sm)] disabled:opacity-40 transition-colors"
              aria-label={tc("previousPage")}
            >
              <span className="material-symbols-rounded text-xl">chevron_left</span>
            </button>
            <span className="tabular px-2 text-xs">{safePage + 1} / {totalPages}</span>
            <button
              onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
              disabled={safePage >= totalPages - 1}
              className="p-1 rounded-[var(--r-sm)] disabled:opacity-40 transition-colors"
              aria-label={tc("nextPage")}
            >
              <span className="material-symbols-rounded text-xl">chevron_right</span>
            </button>
          </div>
        </div>
      )}

      {confirmingId != null && (
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
              {t("cancelOccurrenceConfirmTitle")}
            </p>
            <p className="text-[12.5px] leading-relaxed mb-5" style={{ color: "var(--on-surface-variant)" }}>
              {t("cancelOccurrenceConfirmBody")}
            </p>
            <div className="flex gap-2.5 justify-end">
              <button
                onClick={() => setConfirmingId(null)}
                className="text-sm font-bold px-4 py-2.5"
                style={{ color: "var(--on-surface-variant)" }}
              >
                {t("keepOccurrence")}
              </button>
              <button
                onClick={() => {
                  const id = confirmingId;
                  setConfirmingId(null);
                  if (id != null) cancelMutation.mutate(id);
                }}
                disabled={cancelMutation.isPending}
                className="rounded-xl px-4.5 py-2.5 text-sm font-extrabold disabled:opacity-60"
                style={{ background: "var(--error)", color: "#161611" }}
              >
                {t("cancelOccurrenceConfirm")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
