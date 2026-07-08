"use client";

import { useTranslations } from "next-intl";
import { eachDayOfInterval, endOfMonth, endOfWeek, format, isSameDay, isSameMonth, startOfMonth, startOfWeek } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { useLocale } from "@/lib/hooks/useLocale";
import { ClientAvatar } from "./ClientAvatar";
import { STATUS_STYLE } from "../scheduleStatus";
import type { TrainerCalendarSessionResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;
const MAX_CHIPS_PER_DAY = 3;

interface CalendarMonthViewProps {
  monthAnchor: Date;
  sessions: TrainerCalendarSessionResponse[];
  onSelectDay: (date: Date) => void;
  onSelectSession: (session: TrainerCalendarSessionResponse, anchorEl: HTMLElement) => void;
  /* Narrow-viewport variant (design: D frame) — day cells shrink to a day number
   * + up to 3 status dots instead of chips; tapping a day still opens the agenda. */
  compact?: boolean;
}

function dotColor(status: TrainerCalendarSessionResponse["status"]) {
  const style = STATUS_STYLE[status];
  return style.color === "var(--error)" ? "var(--error)" : "var(--tertiary)";
}

/** Classic month grid (design: B frame) — up to 3 compact chips per cell, "+N further" overflow. */
export function CalendarMonthView({ monthAnchor, sessions, onSelectDay, onSelectSession, compact = false }: CalendarMonthViewProps) {
  const t = useTranslations("admin.calendar");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const today = new Date();

  const monthStart = startOfMonth(monthAnchor);
  const monthEnd = endOfMonth(monthAnchor);
  const gridStart = startOfWeek(monthStart, { weekStartsOn: 1 });
  const gridEnd = endOfWeek(monthEnd, { weekStartsOn: 1 });
  const days = eachDayOfInterval({ start: gridStart, end: gridEnd });

  const sessionsByDay = new Map<string, TrainerCalendarSessionResponse[]>();
  for (const session of sessions) {
    const key = session.scheduledFor;
    if (!sessionsByDay.has(key)) sessionsByDay.set(key, []);
    sessionsByDay.get(key)!.push(session);
  }

  const weekdayLabels = Array.from({ length: 7 }, (_, i) =>
    format(days[i], compact ? "EEEEEE" : "EEEE", { locale: dateLocale }).toUpperCase(),
  );

  return (
    <div className="flex-1 flex flex-col gap-1.5 min-h-0">
      <div className="grid grid-cols-7 gap-1.5 flex-none">
        {weekdayLabels.map((label) => (
          <span key={label} className="text-[10px] font-extrabold tracking-wider px-1" style={{ color: "var(--muted)" }}>
            {label}
          </span>
        ))}
      </div>
      <div className="flex-1 grid grid-cols-7 gap-1.5 min-h-0" style={{ gridAutoRows: "1fr" }}>
        {days.map((day) => {
          const dayIso = format(day, "yyyy-MM-dd");
          const dayIsToday = isSameDay(day, today);
          const inMonth = isSameMonth(day, monthAnchor);
          const daySessions = sessionsByDay.get(dayIso) ?? [];
          const shown = daySessions.slice(0, MAX_CHIPS_PER_DAY);
          const moreCount = daySessions.length - shown.length;

          return (
            <div
              key={dayIso}
              role="button"
              tabIndex={0}
              onClick={() => onSelectDay(day)}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  onSelectDay(day);
                }
              }}
              className={`rounded-xl p-1.5 flex flex-col gap-1 min-w-0 text-left cursor-pointer ${compact ? "items-center justify-center" : ""}`}
              style={{
                background: dayIsToday
                  ? "color-mix(in srgb, var(--tertiary) 6%, var(--surface))"
                  : "var(--surface)",
                border: dayIsToday
                  ? "1.5px solid color-mix(in srgb, var(--tertiary) 50%, transparent)"
                  : "1.5px solid transparent",
                opacity: inMonth ? 1 : 0.4,
                minHeight: compact ? 52 : undefined,
              }}
            >
              {dayIsToday ? (
                <span
                  className="self-start rounded-full px-2 text-[10px] font-extrabold"
                  style={{ background: "var(--tertiary)", color: "#161611" }}
                >
                  {compact ? format(day, "d") : `${format(day, "d")} · ${t("today").toUpperCase()}`}
                </span>
              ) : (
                <span
                  className="text-[11.5px] font-extrabold"
                  style={{ color: inMonth ? "var(--on-surface)" : "var(--on-surface-variant)" }}
                >
                  {inMonth ? format(day, "d") : format(day, "MMM d.", { locale: dateLocale })}
                </span>
              )}

              {compact ? (
                <>
                  {daySessions.length > 0 && (
                    <div className="flex items-center gap-[3px]">
                      {daySessions.slice(0, MAX_CHIPS_PER_DAY).map((session) => (
                        <span
                          key={session.sessionId}
                          className="w-[5px] h-[5px] rounded-full"
                          style={{ background: dotColor(session.status) }}
                        />
                      ))}
                    </div>
                  )}
                  {daySessions.length > MAX_CHIPS_PER_DAY && (
                    <span className="text-[8px] font-bold" style={{ color: "var(--on-tertiary-container)" }}>
                      {t("moreCount", { count: daySessions.length - MAX_CHIPS_PER_DAY })}
                    </span>
                  )}
                </>
              ) : (
                <>
                  {shown.map((session) => {
                    const style = STATUS_STYLE[session.status];
                    const cancelled = session.status === "CANCELLED";
                    return (
                      <button
                        key={session.sessionId}
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          onSelectSession(session, e.currentTarget);
                        }}
                        className="flex items-center gap-1 rounded-md px-1.5 py-0.5 min-w-0 text-left w-full"
                        style={{ background: "var(--surface-container)", opacity: cancelled ? 0.45 : 1 }}
                      >
                        {session.scheduledTime && (
                          <span className="text-[9.5px] font-extrabold tabular shrink-0" style={{ color: "var(--on-surface)" }}>
                            {session.scheduledTime.slice(0, 5)}
                          </span>
                        )}
                        <ClientAvatar clientId={session.clientId} email={session.clientEmail} size={13} />
                        <span
                          className="flex-1 min-w-0 text-[9.5px] font-semibold truncate"
                          style={{ color: "var(--on-surface-variant)", textDecoration: cancelled ? "line-through" : "none" }}
                        >
                          {session.templateName ?? "—"}
                        </span>
                        <span
                          className="material-symbols-rounded text-[11px] shrink-0"
                          style={{ color: style.color, fontVariationSettings: style.fill ? "'FILL' 1" : "'FILL' 0" }}
                        >
                          {style.icon}
                        </span>
                      </button>
                    );
                  })}

                  {moreCount > 0 && (
                    <span className="text-[9.5px] font-bold pl-0.5" style={{ color: "var(--on-tertiary-container)" }}>
                      {t("moreCount", { count: moreCount })}
                    </span>
                  )}
                </>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
