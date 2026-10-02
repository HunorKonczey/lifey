"use client";

import { useTranslations } from "next-intl";
import { addDays, format, isSameDay, startOfDay } from "date-fns";
import { Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import { STATUS_STYLE } from "../scheduleStatus";
import type { TrainerCalendarSessionResponse } from "../types";

interface CalendarAgendaViewProps {
  weekStart: Date;
  sessions: TrainerCalendarSessionResponse[];
  names?: Map<number, string>;
  onSelectSession: (session: TrainerCalendarSessionResponse, anchorEl: HTMLElement) => void;
}

/**
 * The week on a narrow screen (W8-A, below the desktop width): days stacked, empty days left out, one row per workout —
 * time without seconds, the client, the workout and the status in words. Same tokens and status language as the grid.
 */
export function CalendarAgendaView({ weekStart, sessions, names, onSelectSession }: CalendarAgendaViewProps) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const fmt = useFormat();
  const today = startOfDay(new Date());

  const byDay = new Map<string, TrainerCalendarSessionResponse[]>();
  for (const s of sessions) {
    if (!byDay.has(s.scheduledFor)) byDay.set(s.scheduledFor, []);
    byDay.get(s.scheduledFor)!.push(s);
  }
  const activeDays = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)).filter((d) => (byDay.get(format(d, "yyyy-MM-dd")) ?? []).length > 0);

  return (
    <div className="flex flex-col gap-5" data-testid="calendar-agenda">
      {activeDays.map((day) => {
        const iso = format(day, "yyyy-MM-dd");
        const isToday = isSameDay(day, today);
        const list = (byDay.get(iso) ?? []).slice().sort((a, b) => (a.scheduledTime ?? "99").localeCompare(b.scheduledTime ?? "99"));
        return (
          <section key={iso} className="flex flex-col gap-2" aria-label={`${fmt.weekdayShort(day)}, ${fmt.shortDate(day)}`}>
            <div className="flex items-center gap-2">
              {isToday && (
                <span className="inline-flex items-center px-2.5 type-body-s" style={{ height: 24, borderRadius: 999, background: "var(--primary)", color: "var(--on-primary)", fontWeight: 800 }}>
                  {t("today")}
                </span>
              )}
              <h3 style={{ fontSize: 15, fontWeight: 800 }}>{fmt.weekdayShort(day)}, {fmt.shortDate(day)}</h3>
            </div>
            <ul className="flex flex-col gap-2">
              {list.map((s) => {
                const style = STATUS_STYLE[s.status];
                const cancelled = s.status === "CANCELLED";
                return (
                  <li key={s.sessionId}>
                    <button
                      type="button"
                      onClick={(e) => onSelectSession(s, e.currentTarget)}
                      data-testid="calendar-session-card"
                      data-client-email={s.clientEmail}
                      className="lifey-button flex w-full items-center gap-3 px-3.5 py-3 text-left"
                      style={{ borderRadius: "var(--r-control)", background: "var(--card)", boxShadow: "var(--edge-card)", opacity: cancelled ? 0.6 : 1 }}
                    >
                      <span className="num shrink-0" style={{ width: 48, fontWeight: 800, color: s.scheduledTime ? "var(--text)" : "var(--text-3)" }}>
                        {s.scheduledTime ? fmt.time(new Date(`${s.scheduledFor}T${s.scheduledTime}`)) : t("restOfDayShort")}
                      </span>
                      <ClientAvatar clientId={s.clientId} email={s.clientEmail} size={28} />
                      <span className="flex flex-col flex-1 min-w-0">
                        <span className="truncate" style={{ fontWeight: 700, textDecoration: cancelled ? "line-through" : "none" }}>{names?.get(s.clientId) ?? nameFor(s.clientEmail)}</span>
                        <span className="type-body-s truncate" style={{ color: "var(--text-2)" }}>{s.templateName ?? tSchedule("unnamedTemplate")}</span>
                      </span>
                      <span className="inline-flex items-center gap-1.5 px-2.5 type-body-s shrink-0" style={{ height: 26, borderRadius: 999, background: style.bg, color: style.color, fontWeight: 700, boxShadow: style.bg === "transparent" ? "inset 0 0 0 1px var(--hairline)" : undefined }}>
                        <Icon name={style.icon} size={14} fill={style.fill ? 1 : 0} />
                        {tSchedule(`status.${s.status}`)}
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          </section>
        );
      })}
    </div>
  );
}
