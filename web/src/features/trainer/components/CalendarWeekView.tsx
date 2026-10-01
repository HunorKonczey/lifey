"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { format, isBefore, isSameDay, startOfDay } from "date-fns";
import { Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { bucketSessions, buildHourRows, gapKey, occupiedHours } from "../calendarGrid";
import { nameFor } from "./ClientAvatar";
import type { OccurrenceStatus, TrainerCalendarSessionResponse } from "../types";

/** The 3 px bar of an event card: done green, scheduled primary, missed heart — and the status word beside it. */
const BAR: Record<OccurrenceStatus, string> = {
  DONE: "var(--metric-protein)",
  UPCOMING: "var(--primary)",
  MISSED: "var(--heart)",
  CANCELLED: "var(--text-3)",
};

interface CalendarWeekViewProps {
  /** The columns: seven for a week, one for the day view. */
  days: Date[];
  sessions: TrainerCalendarSessionResponse[];
  /** Real client names by id (the session carries only the e-mail); the e-mail-derived name is the fallback. */
  names?: Map<number, string>;
  /** An empty cell was clicked: the day, and "HH:00" for an hour cell or null for the "no time" row. */
  onScheduleSlot: (dateIso: string, time: string | null) => void;
  onSelectSession: (session: TrainerCalendarSessionResponse, anchorEl: HTMLElement) => void;
}

/**
 * The week as a real grid (W8-A): days as columns, hours as rows, today's column tinted and its header a pill. Runs of
 * empty hours fold into one "⤢ 10:00–15:00 · nincs esemény · kinyitás" row; sessions without a time sit in a "no time"
 * row on top; every event is a card with a status bar *and* the status in words, never colour alone. Clicking an empty
 * cell asks for a workout at that day and hour.
 */
export function CalendarWeekView({ days, sessions, names, onScheduleSlot, onSelectSession }: CalendarWeekViewProps) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const fmt = useFormat();
  const today = startOfDay(new Date());
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  const { cells, untimed } = useMemo(() => bucketSessions(sessions), [sessions]);
  const rows = useMemo(() => buildHourRows(occupiedHours(sessions), { expanded }), [sessions, expanded]);
  const hasUntimed = untimed.size > 0;
  const hourLabel = (h: number) => fmt.time(new Date(2000, 0, 1, h));
  const cols = `64px repeat(${days.length}, minmax(0, 1fr))`;
  const pad = (h: number) => `${String(h).padStart(2, "0")}:00`;

  const card = (s: TrainerCalendarSessionResponse) => {
    const cancelled = s.status === "CANCELLED";
    const name = names?.get(s.clientId) ?? nameFor(s.clientEmail);
    return (
      <button
        key={s.sessionId}
        type="button"
        onClick={(e) => onSelectSession(s, e.currentTarget)}
        data-testid="calendar-session-card"
        data-client-email={s.clientEmail}
        className="lifey-button relative z-10 flex flex-col text-left min-w-0 py-1.5 pl-3 pr-2"
        style={{ borderRadius: 10, background: "var(--nested)", opacity: cancelled ? 0.6 : 1 }}
      >
        <span aria-hidden className="absolute left-0 top-1.5 bottom-1.5" style={{ width: 3, borderRadius: 2, background: BAR[s.status] }} />
        <span className="truncate" style={{ fontSize: 13, fontWeight: 700, textDecoration: cancelled ? "line-through" : "none" }}>{name}</span>
        <span className="truncate" style={{ fontSize: 12, fontWeight: 600, color: "var(--text-2)" }}>
          {s.templateName ?? tSchedule("unnamedTemplate")} · {tSchedule(`status.${s.status}`)}
        </span>
      </button>
    );
  };

  return (
    <div className="overflow-x-auto" style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }} data-testid="calendar-week-grid">
      <div role="grid" aria-label={t("gridAria")} style={{ minWidth: days.length > 1 ? 760 : undefined }}>
        <div role="row" className="grid sticky top-0 z-20" style={{ gridTemplateColumns: cols, background: "var(--card)", borderTopLeftRadius: "var(--r-card)", borderTopRightRadius: "var(--r-card)" }}>
          <div role="columnheader" aria-label={t("hourColumn")} />
          {days.map((day) => {
            const isToday = isSameDay(day, today);
            return (
              <div key={day.getTime()} role="columnheader" className="flex items-center justify-center gap-1.5 py-3" style={{ background: isToday ? "color-mix(in srgb, var(--primary) 4%, transparent)" : undefined }}>
                <span className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 700 }}>{fmt.weekdayShort(day)}</span>
                <span
                  className="num inline-flex items-center justify-center"
                  style={{ minWidth: 28, height: 28, padding: "0 6px", borderRadius: 999, fontWeight: 800, background: isToday ? "var(--primary)" : "transparent", color: isToday ? "var(--on-primary)" : "var(--text)" }}
                  aria-label={isToday ? `${format(day, "d")}, ${t("today")}` : undefined}
                >
                  {format(day, "d")}
                </span>
              </div>
            );
          })}
        </div>

        {hasUntimed && (
          <div role="row" className="grid" style={{ gridTemplateColumns: cols, borderTop: "1px solid var(--hairline)" }}>
            <div role="rowheader" className="type-body-s px-2 py-2 text-right" style={{ color: "var(--text-3)" }}>{t("noTimeRow")}</div>
            {days.map((day) => {
              const iso = format(day, "yyyy-MM-dd");
              return (
                <div key={iso} role="gridcell" className="flex flex-col gap-1 p-1 min-w-0" style={{ background: isSameDay(day, today) ? "color-mix(in srgb, var(--primary) 4%, transparent)" : undefined }}>
                  {(untimed.get(iso) ?? []).map(card)}
                </div>
              );
            })}
          </div>
        )}

        {rows.map((row) => {
          if (row.kind === "gap") {
            return (
              <div key={`gap-${row.from}`} role="row" style={{ borderTop: "1px solid var(--hairline)" }}>
                <button
                  type="button"
                  onClick={() => setExpanded((prev) => new Set(prev).add(gapKey(row.from, row.to)))}
                  className="lifey-button flex w-full items-center justify-center gap-2 py-2.5 type-body-s"
                  style={{ color: "var(--text-2)", fontWeight: 600 }}
                >
                  <Icon name="unfold_more" size={18} />
                  {t("gapRow", { from: hourLabel(row.from), to: hourLabel(row.to + 1) })}
                </button>
              </div>
            );
          }
          return (
            <div key={row.hour} role="row" className="grid" style={{ gridTemplateColumns: cols, borderTop: "1px solid var(--hairline)", minHeight: 64 }}>
              <div role="rowheader" className="type-body-s px-2 pt-2 text-right num" style={{ color: "var(--text-3)" }}>{hourLabel(row.hour)}</div>
              {days.map((day) => {
                const iso = format(day, "yyyy-MM-dd");
                const here = cells.get(`${iso}|${row.hour}`) ?? [];
                const past = isBefore(day, today);
                return (
                  <div
                    key={iso}
                    role="gridcell"
                    className="group relative flex flex-col gap-1 p-1 min-w-0"
                    style={{ background: isSameDay(day, today) ? "color-mix(in srgb, var(--primary) 4%, transparent)" : undefined }}
                  >
                    {!past && here.length === 0 && (
                      <button
                        type="button"
                        onClick={() => onScheduleSlot(iso, pad(row.hour))}
                        aria-label={t("scheduleSlotAria", { date: fmt.shortDate(day), time: hourLabel(row.hour) })}
                        className="absolute inset-0 flex items-center justify-center opacity-0 hover:opacity-100 focus-visible:opacity-100"
                        style={{ color: "var(--text-3)" }}
                      >
                        <Icon name="add" size={18} />
                      </button>
                    )}
                    {here.map(card)}
                  </div>
                );
              })}
            </div>
          );
        })}
      </div>
    </div>
  );
}
