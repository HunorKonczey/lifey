"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { addDays, addMonths, addWeeks, endOfMonth, endOfWeek, format, startOfMonth, startOfWeek } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useLocale } from "@/lib/hooks/useLocale";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { CalendarWeekView } from "./CalendarWeekView";
import { CalendarMonthView } from "./CalendarMonthView";
import { CalendarSessionPeek } from "./CalendarSessionPeek";
import { ScheduleWorkoutDrawer } from "./ScheduleWorkoutDrawer";
import type { TrainerCalendarSessionResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

type View = "week" | "month";

function formatWeekRange(start: Date, end: Date, locale: typeof enUS) {
  const sameMonth = start.getMonth() === end.getMonth();
  if (sameMonth) return `${format(start, "MMM d", { locale })}–${format(end, "d.", { locale })}`;
  return `${format(start, "MMM d.", { locale })} – ${format(end, "MMM d.", { locale })}`;
}

/**
 * Trainer calendar (docs/personal_trainer/12-edzo-naptar-terv.md, design:
 * design/Lifey Calendar.dc.html) — every active client's scheduled workouts
 * in one view. Client filter, the "Lemondottak" toggle and the session-peek
 * popover land in follow-up steps; cancelled occurrences are hidden by
 * default until the toggle exists (decision #7 in the design doc).
 */
export function TrainerCalendar() {
  const t = useTranslations("admin.calendar");
  const locale = useLocale((s) => s.locale);
  const dateLocale = DATE_LOCALES[locale];

  const [view, setView] = useState<View>("week");
  const [anchorDate, setAnchorDate] = useState(() => new Date());
  const [scheduleDrawerDate, setScheduleDrawerDate] = useState<string | null>(null);
  const [peek, setPeek] = useState<{ session: TrainerCalendarSessionResponse; anchor: HTMLElement } | null>(null);

  const weekStart = startOfWeek(anchorDate, { weekStartsOn: 1 });
  const weekEnd = addDays(weekStart, 6);

  const monthStart = startOfMonth(anchorDate);
  const monthGridStart = startOfWeek(monthStart, { weekStartsOn: 1 });
  const monthGridEnd = endOfWeek(endOfMonth(anchorDate), { weekStartsOn: 1 });

  const rangeStart = view === "week" ? weekStart : monthGridStart;
  const rangeEnd = view === "week" ? weekEnd : monthGridEnd;
  const from = format(rangeStart, "yyyy-MM-dd");
  const to = format(rangeEnd, "yyyy-MM-dd");

  const { data: sessions, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerCalendar.range(from, to),
    queryFn: () => trainerApi.calendarSessions(from, to),
  });
  const visibleSessions = (sessions ?? []).filter((s) => s.status !== "CANCELLED");

  const periodLabel =
    view === "week"
      ? formatWeekRange(weekStart, weekEnd, dateLocale)
      : locale === "hu"
        ? format(anchorDate, "yyyy. MMMM", { locale: dateLocale })
        : format(anchorDate, "MMMM yyyy", { locale: dateLocale });

  const goToday = () => setAnchorDate(new Date());
  const goPrev = () => setAnchorDate((d) => (view === "week" ? addWeeks(d, -1) : addMonths(d, -1)));
  const goNext = () => setAnchorDate((d) => (view === "week" ? addWeeks(d, 1) : addMonths(d, 1)));

  return (
    <div className="flex flex-col gap-3" style={{ minHeight: "calc(100vh - 120px)" }}>
      <div
        className="rounded-2xl px-2.5 py-2 flex items-center gap-2.5 flex-none flex-wrap"
        style={{ background: "var(--surface-high)" }}
      >
        <button
          onClick={goToday}
          className="rounded-[11px] px-3.5 py-2 text-[12.5px] font-bold"
          style={{ border: "1px solid var(--outline)", color: "var(--on-surface)" }}
        >
          {t("today")}
        </button>
        <div className="flex gap-1">
          <button
            onClick={goPrev}
            aria-label={view === "week" ? t("previousWeek") : t("previousMonth")}
            className="w-[34px] h-[34px] rounded-[11px] flex items-center justify-center"
            style={{ background: "var(--bg)", color: "var(--on-surface-variant)" }}
          >
            <span className="material-symbols-rounded text-[19px]">chevron_left</span>
          </button>
          <button
            onClick={goNext}
            aria-label={view === "week" ? t("nextWeek") : t("nextMonth")}
            className="w-[34px] h-[34px] rounded-[11px] flex items-center justify-center"
            style={{ background: "var(--bg)", color: "var(--on-surface-variant)" }}
          >
            <span className="material-symbols-rounded text-[19px]">chevron_right</span>
          </button>
        </div>
        <span className="text-[15.5px] font-extrabold ml-1" style={{ color: "var(--on-surface)" }}>
          {periodLabel}
        </span>
        <div className="flex-1" />
        <SegmentedControl
          options={[
            { value: "week", label: t("week") },
            { value: "month", label: t("month") },
          ]}
          value={view}
          onChange={setView}
          size="sm"
          activeBackground="var(--tertiary)"
          activeColor="#161611"
        />
      </div>

      {isLoading ? (
        <div className="grid grid-cols-7 gap-2">
          {Array.from({ length: 7 }).map((_, i) => (
            <Skeleton key={i} variant="card" />
          ))}
        </div>
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : view === "week" ? (
        <CalendarWeekView
          weekStart={weekStart}
          sessions={visibleSessions}
          onScheduleDay={setScheduleDrawerDate}
          onSelectSession={(session, anchor) => setPeek({ session, anchor })}
        />
      ) : (
        <CalendarMonthView
          monthAnchor={anchorDate}
          sessions={visibleSessions}
          onSelectDay={(day) => {
            setAnchorDate(day);
            setView("week");
          }}
          onSelectSession={(session, anchor) => setPeek({ session, anchor })}
        />
      )}

      {scheduleDrawerDate && (
        <ScheduleWorkoutDrawer
          initialStartDate={scheduleDrawerDate}
          onClose={() => setScheduleDrawerDate(null)}
        />
      )}

      {peek && (
        <CalendarSessionPeek
          key={peek.session.sessionId}
          session={peek.session}
          anchorEl={peek.anchor}
          onClose={() => setPeek(null)}
        />
      )}
    </div>
  );
}
