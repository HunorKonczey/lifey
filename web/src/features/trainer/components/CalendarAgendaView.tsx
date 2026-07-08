"use client";

import { useTranslations } from "next-intl";
import { addDays, format, isSameDay, startOfDay } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { useLocale } from "@/lib/hooks/useLocale";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import { STATUS_STYLE } from "../scheduleStatus";
import type { TrainerCalendarSessionResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

interface CalendarAgendaViewProps {
  weekStart: Date;
  sessions: TrainerCalendarSessionResponse[];
  onSelectSession: (session: TrainerCalendarSessionResponse, anchorEl: HTMLElement) => void;
}

/** Narrow-viewport stand-in for the week grid (design: D frame, "tablet alatt")
 *  — days stacked, empty days omitted, same card content as the grid but a
 *  single-row layout. */
export function CalendarAgendaView({ weekStart, sessions, onSelectSession }: CalendarAgendaViewProps) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const today = startOfDay(new Date());

  const days = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
  const sessionsByDay = new Map<string, TrainerCalendarSessionResponse[]>();
  for (const session of sessions) {
    const key = session.scheduledFor;
    if (!sessionsByDay.has(key)) sessionsByDay.set(key, []);
    sessionsByDay.get(key)!.push(session);
  }
  const activeDays = days.filter((d) => (sessionsByDay.get(format(d, "yyyy-MM-dd")) ?? []).length > 0);

  return (
    <div className="flex flex-col gap-4">
      {activeDays.map((day) => {
        const dayIso = format(day, "yyyy-MM-dd");
        const dayIsToday = isSameDay(day, today);
        const daySessions = sessionsByDay.get(dayIso) ?? [];

        return (
          <div key={dayIso} className="flex flex-col gap-1.5">
            <div className="flex items-center gap-2">
              {dayIsToday && (
                <span
                  className="rounded-full px-2.5 py-0.5 text-[9.5px] font-extrabold tracking-wide"
                  style={{ background: "var(--tertiary)", color: "#161611" }}
                >
                  {t("today").toUpperCase()}
                </span>
              )}
              <span className="text-[12.5px] font-extrabold" style={{ color: "var(--on-surface)" }}>
                {format(day, "EEEE, MMM d.", { locale: dateLocale })}
              </span>
            </div>
            <div className="flex flex-col gap-1.5">
              {daySessions.map((session) => {
                const style = STATUS_STYLE[session.status];
                const cancelled = session.status === "CANCELLED";
                return (
                  <button
                    key={session.sessionId}
                    onClick={(e) => onSelectSession(session, e.currentTarget)}
                    className="rounded-2xl px-3 py-2.5 flex items-center gap-2.5 text-left w-full"
                    style={{ background: "var(--surface-container)", opacity: cancelled ? 0.5 : 1 }}
                  >
                    <span
                      className="w-11 shrink-0 text-[12.5px] font-extrabold tabular"
                      style={{ color: session.scheduledTime ? "var(--on-surface)" : "var(--muted)" }}
                    >
                      {session.scheduledTime ? session.scheduledTime.slice(0, 5) : t("restOfDayShort")}
                    </span>
                    <ClientAvatar clientId={session.clientId} email={session.clientEmail} size={24} />
                    <div className="flex-1 min-w-0">
                      <div className="text-[12.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                        {nameFor(session.clientEmail)}
                      </div>
                      <div
                        className="text-[10.5px] mt-0.5 truncate"
                        style={{ color: "var(--on-surface-variant)", textDecoration: cancelled ? "line-through" : "none" }}
                      >
                        {session.templateName ?? tSchedule("unnamedTemplate")}
                      </div>
                    </div>
                    <span
                      className="flex items-center gap-1 rounded-full text-[10px] font-extrabold px-2 py-0.5 shrink-0"
                      style={{
                        background: style.bg,
                        color: style.color,
                        border: style.bg === "transparent" ? "1px solid var(--outline)" : "none",
                      }}
                    >
                      <span
                        className="material-symbols-rounded text-xs"
                        style={{ fontVariationSettings: style.fill ? "'FILL' 1" : "'FILL' 0" }}
                      >
                        {style.icon}
                      </span>
                      {tSchedule(`status.${session.status}`)}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        );
      })}
    </div>
  );
}
