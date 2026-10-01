"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { differenceInCalendarWeeks, format, startOfWeek } from "date-fns";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Card, ConfirmModal, Icon, IconButton } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { STATUS_STYLE } from "../scheduleStatus";
import type { ScheduledSessionResponse } from "../types";

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
  const fmt = useFormat();
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
    <Card variant="card" className="flex flex-col gap-4" data-testid="schedule-timeline">
      <h3 style={{ fontSize: 18, fontWeight: 800 }}>{t("timeline")}</h3>
      <div className="flex flex-col gap-5">
        {pageGroups.map(({ key, label, items }) => (
          <div key={key} className="grid grid-cols-1 md:grid-cols-[120px_minmax(0,1fr)] gap-2 md:gap-4">
            <p className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 800, letterSpacing: "0.06em", textTransform: "uppercase" }}>{label}</p>
            <ul className="flex flex-col gap-2">
              {items.map((occ) => {
                const style = STATUS_STYLE[occ.status];
                const cancelled = occ.status === "CANCELLED";
                const clickable = occ.status === "DONE" && !!onViewSession;
                const day = new Date(`${occ.scheduledFor}T00:00:00`);
                const content = (
                  <>
                    <span className="num shrink-0" style={{ fontWeight: 800, width: 96 }}>
                      {fmt.weekdayShort(day)} · {fmt.shortDate(day)}
                      {occ.scheduledTime && <span className="block type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>{occ.scheduledTime.slice(0, 5)}</span>}
                    </span>
                    <span className="flex-1 min-w-0 flex flex-col">
                      <span className="truncate" style={{ fontWeight: 700, textDecoration: cancelled ? "line-through" : "none" }}>
                        {occ.templateName ?? t("unnamedTemplate")}
                      </span>
                      {occ.programAssignmentId != null && programNamesById?.[occ.programAssignmentId] && (
                        <span className="inline-flex items-center gap-1 type-body-s truncate" style={{ color: "var(--text-2)" }}>
                          <Icon name="event_repeat" size={14} />
                          {programNamesById[occ.programAssignmentId]}
                        </span>
                      )}
                    </span>
                    <span
                      className="inline-flex items-center gap-1.5 px-2.5 type-body-s shrink-0"
                      style={{ height: 28, borderRadius: 999, background: style.bg, color: style.color, fontWeight: 700, boxShadow: style.bg === "transparent" ? "inset 0 0 0 1px var(--hairline)" : undefined }}
                    >
                      <Icon name={style.icon} size={16} fill={style.fill ? 1 : 0} />
                      {t(`status.${occ.status}`)}
                    </span>
                    {clickable && <Icon name="chevron_right" size={20} color="var(--text-3)" />}
                  </>
                );
                return (
                  <li key={occ.sessionId} className="flex items-center gap-2" style={{ opacity: cancelled ? 0.55 : 1 }}>
                    {clickable ? (
                      <button type="button" onClick={() => onViewSession!(occ.sessionId)} className="lifey-button flex flex-1 min-w-0 items-center gap-3 px-3.5 py-3 text-left" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
                        {content}
                      </button>
                    ) : (
                      <div className="flex flex-1 min-w-0 items-center gap-3 px-3.5 py-3" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
                        {content}
                      </div>
                    )}
                    {occ.status === "UPCOMING" && (
                      // The row sits at the card edge: the tooltip hangs from the button's right edge so its hidden box never widens the page.
                      <span className="inline-flex [&_.lifey-tooltip]:left-auto [&_.lifey-tooltip]:right-0 [&_.lifey-tooltip]:translate-x-0">
                        <IconButton icon="event_busy" label={t("cancelOccurrence")} onClick={() => setConfirmingId(occ.sessionId)} />
                      </span>
                    )}
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between type-body-s" style={{ color: "var(--text-2)" }}>
          <span className="tabular">
            {tc("rangeOf", { from: safePage * PAGE_SIZE + 1, to: Math.min(safePage * PAGE_SIZE + PAGE_SIZE, totalCount), total: totalCount })}
          </span>
          <div className="flex items-center gap-1">
            <IconButton icon="chevron_left" label={tc("previousPage")} onClick={() => setPage((p) => Math.max(0, p - 1))} disabled={safePage === 0} />
            <span className="tabular px-2">{safePage + 1} / {totalPages}</span>
            <IconButton icon="chevron_right" label={tc("nextPage")} onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))} disabled={safePage >= totalPages - 1} />
          </div>
        </div>
      )}

      <ConfirmModal
        open={confirmingId != null}
        onClose={() => setConfirmingId(null)}
        onConfirm={() => {
          const id = confirmingId;
          setConfirmingId(null);
          if (id != null) cancelMutation.mutate(id);
        }}
        icon="event_busy"
        title={t("cancelOccurrenceConfirmTitle")}
        body={t("cancelOccurrenceConfirmBody")}
        cancelLabel={t("keepOccurrence")}
        confirmLabel={t("cancelOccurrenceConfirm")}
      />
    </Card>
  );
}
