"use client";

import { useTranslations } from "next-intl";
import { addDays, format, isBefore, isSameDay, startOfDay } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { useLocale } from "@/lib/hooks/useLocale";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import { STATUS_STYLE } from "../scheduleStatus";
import type { TrainerCalendarSessionResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

interface CalendarWeekViewProps {
  weekStart: Date;
  sessions: TrainerCalendarSessionResponse[];
  onScheduleDay: (dateIso: string) => void;
  onSelectSession: (session: TrainerCalendarSessionResponse, anchorEl: HTMLElement) => void;
}

/** Card-column week grid (design: A frame) — deliberately not an hour grid, since
 *  many occurrences have no time of day; see docs/personal_trainer/12-edzo-naptar-terv.md. */
export function CalendarWeekView({ weekStart, sessions, onScheduleDay, onSelectSession }: CalendarWeekViewProps) {
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

  return (
    <div className="flex-1 grid grid-cols-7 gap-2 min-h-0">
      {days.map((day) => {
        const dayIso = format(day, "yyyy-MM-dd");
        const dayIsToday = isSameDay(day, today);
        const isPast = isBefore(day, today);
        const daySessions = sessionsByDay.get(dayIso) ?? [];
        const firstUntimedIndex = daySessions.findIndex((s) => !s.scheduledTime);
        const hasDivider = firstUntimedIndex > 0;

        return (
          <div
            key={dayIso}
            className="rounded-2xl p-2 flex flex-col gap-1.5 min-w-0"
            style={{
              background: dayIsToday
                ? "color-mix(in srgb, var(--tertiary) 6%, var(--surface))"
                : "var(--surface)",
              border: dayIsToday
                ? "1.5px solid color-mix(in srgb, var(--tertiary) 50%, transparent)"
                : "1.5px solid transparent",
            }}
          >
            <div className="flex items-start justify-between gap-1 px-1.5 pt-1 pb-0.5">
              <div>
                <div
                  className="text-[10px] font-extrabold tracking-wider"
                  style={{ color: isPast ? "var(--muted)" : dayIsToday ? "var(--on-tertiary-container)" : "var(--on-surface-variant)" }}
                >
                  {format(day, "EEEE", { locale: dateLocale }).toUpperCase()}
                </div>
                <div
                  className="text-base font-extrabold"
                  style={{ color: isPast ? "var(--on-surface-variant)" : "var(--on-surface)" }}
                >
                  {format(day, "MMM d.", { locale: dateLocale })}
                </div>
              </div>
              {dayIsToday ? (
                <span
                  className="rounded-full px-2.5 py-0.5 text-[9.5px] font-extrabold tracking-wide"
                  style={{ background: "var(--tertiary)", color: "#161611" }}
                >
                  {t("today").toUpperCase()}
                </span>
              ) : (
                !isPast && (
                  <button
                    onClick={() => onScheduleDay(dayIso)}
                    aria-label={t("scheduleDayAria", { date: format(day, "MMM d.", { locale: dateLocale }) })}
                    className="w-[26px] h-[26px] rounded-[9px] flex items-center justify-center shrink-0 opacity-0 hover:opacity-100 focus-visible:opacity-100 transition-opacity"
                    style={{ background: "var(--surface-high)", color: "var(--on-surface)" }}
                  >
                    <span className="material-symbols-rounded text-[17px]">add</span>
                  </button>
                )
              )}
            </div>

            {daySessions.map((session, index) => {
              const style = STATUS_STYLE[session.status];
              const cancelled = session.status === "CANCELLED";
              const showDividerBefore = hasDivider && index === firstUntimedIndex;
              return (
                <div key={session.sessionId}>
                  {showDividerBefore && (
                    <div className="flex items-center gap-1.5 my-0.5">
                      <div className="flex-1 h-px" style={{ background: "var(--surface-high)" }} />
                      <span
                        className="text-[9px] font-bold tracking-wide uppercase"
                        style={{ color: "var(--muted)" }}
                      >
                        {t("restOfDay")}
                      </span>
                      <div className="flex-1 h-px" style={{ background: "var(--surface-high)" }} />
                    </div>
                  )}
                  <button
                    onClick={(e) => onSelectSession(session, e.currentTarget)}
                    data-testid="calendar-session-card"
                    data-client-email={session.clientEmail}
                    className="rounded-2xl px-2.5 py-2.5 flex flex-col gap-1.5 text-left w-full"
                    style={{ background: "var(--surface-container)", opacity: cancelled ? 0.5 : 1 }}
                  >
                    <div className="flex items-center justify-between gap-1.5">
                      {session.scheduledTime ? (
                        <span className="text-[13px] font-extrabold tabular" style={{ color: "var(--on-surface)" }}>
                          {session.scheduledTime.slice(0, 5)}
                        </span>
                      ) : (
                        <span />
                      )}
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
                    </div>
                    <div className="flex items-center gap-1.5 min-w-0">
                      <ClientAvatar clientId={session.clientId} email={session.clientEmail} size={20} />
                      <span className="text-xs font-bold truncate" style={{ color: "var(--on-surface)" }}>
                        {nameFor(session.clientEmail)}
                      </span>
                    </div>
                    <div
                      className="text-[11px] font-semibold truncate"
                      style={{ color: "var(--on-surface-variant)", textDecoration: cancelled ? "line-through" : "none" }}
                    >
                      {session.templateName ?? tSchedule("unnamedTemplate")}
                    </div>
                  </button>
                </div>
              );
            })}
          </div>
        );
      })}
    </div>
  );
}
