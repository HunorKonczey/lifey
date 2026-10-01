"use client";

import { useTranslations } from "next-intl";
import { eachDayOfInterval, endOfMonth, endOfWeek, format, isSameDay, isSameMonth, startOfMonth, startOfWeek } from "date-fns";
import { useFormat } from "@/lib/format/useFormat";
import type { OccurrenceStatus, TrainerCalendarSessionResponse } from "../types";

const MAX_DOTS = 6;
const DOT: Record<OccurrenceStatus, string> = {
  UPCOMING: "var(--primary)",
  DONE: "var(--metric-protein)",
  MISSED: "var(--heart)",
  CANCELLED: "var(--text-3)",
};

interface CalendarMonthViewProps {
  monthAnchor: Date;
  sessions: TrainerCalendarSessionResponse[];
  /** A day was chosen: the calendar opens it (the day view). */
  onSelectDay: (date: Date) => void;
  /** Kept for the shared signature with the week view; the month shows counts, so there is no event to pick. */
  onSelectSession?: (session: TrainerCalendarSessionResponse, anchorEl: HTMLElement) => void;
  /** The phone variant: smaller cells, the count only. */
  compact?: boolean;
}

/**
 * The month (W8.3): a Monday-first grid where every day is one button — the day number (today a primary pill), "3
 * edzés" and a row of status dots (one per workout, up to six, then "+N"). Counts rather than chips: text in a cell
 * a seventh of the width cut every name, and the dots keep the status without colour alone because the cell's label
 * spells it out ("szept. 29., hétfő: 2 kész, 1 kihagyott"). A click opens that day.
 */
export function CalendarMonthView({ monthAnchor, sessions, onSelectDay, compact = false }: CalendarMonthViewProps) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const fmt = useFormat();
  const today = new Date();

  const days = eachDayOfInterval({ start: startOfWeek(startOfMonth(monthAnchor), { weekStartsOn: 1 }), end: endOfWeek(endOfMonth(monthAnchor), { weekStartsOn: 1 }) });
  const byDay = new Map<string, TrainerCalendarSessionResponse[]>();
  for (const s of sessions) {
    if (!byDay.has(s.scheduledFor)) byDay.set(s.scheduledFor, []);
    byDay.get(s.scheduledFor)!.push(s);
  }

  const summary = (list: TrainerCalendarSessionResponse[]) => {
    const parts = (["DONE", "UPCOMING", "MISSED", "CANCELLED"] as const)
      .map((st) => [st, list.filter((s) => s.status === st).length] as const)
      .filter(([, n]) => n > 0)
      .map(([st, n]) => `${n} ${tSchedule(`status.${st}`)}`);
    return parts.join(", ");
  };

  return (
    <div className="flex flex-col gap-2" data-testid="calendar-month-grid">
      <div className="grid grid-cols-7 gap-1.5" aria-hidden>
        {days.slice(0, 7).map((d) => (
          <span key={d.getTime()} className="type-body-s px-1.5" style={{ color: "var(--text-3)", fontWeight: 700 }}>
            {fmt.weekdayShort(d)}
          </span>
        ))}
      </div>
      <div className="grid grid-cols-7 gap-1.5">
        {days.map((day) => {
          const iso = format(day, "yyyy-MM-dd");
          const isToday = isSameDay(day, today);
          const inMonth = isSameMonth(day, monthAnchor);
          const list = byDay.get(iso) ?? [];
          const dots = list.slice(0, MAX_DOTS);
          return (
            <button
              key={iso}
              type="button"
              onClick={() => onSelectDay(day)}
              aria-label={`${fmt.shortDate(day)}${list.length ? `: ${summary(list)}` : ""}`}
              className="lifey-button flex flex-col items-start gap-1 text-left p-2 min-w-0"
              style={{
                borderRadius: "var(--r-control)",
                minHeight: compact ? 56 : 92,
                background: isToday ? "color-mix(in srgb, var(--primary) 6%, var(--card))" : "var(--card)",
                boxShadow: isToday ? "inset 0 0 0 1.5px color-mix(in srgb, var(--primary) 50%, transparent)" : "var(--edge-card)",
                opacity: inMonth ? 1 : 0.45,
              }}
            >
              <span
                className="num inline-flex items-center justify-center"
                style={{ minWidth: 24, height: 24, padding: "0 6px", borderRadius: 999, fontWeight: 800, fontSize: 13, background: isToday ? "var(--primary)" : "transparent", color: isToday ? "var(--on-primary)" : inMonth ? "var(--text)" : "var(--text-2)" }}
              >
                {format(day, "d")}
              </span>
              {list.length > 0 && (
                <>
                  {!compact && <span className="type-body-s" style={{ fontWeight: 700 }}>{t("workoutsCount", { count: list.length })}</span>}
                  <span className="flex flex-wrap items-center gap-[3px]" aria-hidden>
                    {dots.map((s) => (
                      <span key={s.sessionId} style={{ width: 7, height: 7, borderRadius: 999, background: DOT[s.status], opacity: s.status === "CANCELLED" ? 0.5 : 1 }} />
                    ))}
                    {list.length > MAX_DOTS && <span className="type-body-s" style={{ color: "var(--text-2)", fontSize: 11 }}>+{list.length - MAX_DOTS}</span>}
                  </span>
                </>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}
