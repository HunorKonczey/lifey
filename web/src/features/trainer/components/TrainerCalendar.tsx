"use client";

import { useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { addDays, addMonths, addWeeks, endOfMonth, endOfWeek, format, isBefore, startOfDay, startOfMonth, startOfWeek } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useLocale } from "@/lib/hooks/useLocale";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { Switch } from "@/components/ui/Switch";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { CalendarWeekView } from "./CalendarWeekView";
import { CalendarMonthView } from "./CalendarMonthView";
import { CalendarAgendaView } from "./CalendarAgendaView";
import { CalendarWeekSkeleton, CalendarMonthSkeleton, CalendarAgendaSkeleton } from "./CalendarSkeleton";
import { CalendarSessionPeek } from "./CalendarSessionPeek";
import { CalendarClientFilter } from "./CalendarClientFilter";
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
 * in one view.
 */
export function TrainerCalendar() {
  const t = useTranslations("admin.calendar");
  const tDashboard = useTranslations("admin.dashboard");
  const tSchedule = useTranslations("admin.schedule");
  const locale = useLocale((s) => s.locale);
  const dateLocale = DATE_LOCALES[locale];
  /* Below tablet width the 7-column week grid doesn't fit — collapse to an
   * agenda list / dot-month instead (design: D frame, "tablet alatt"). */
  const narrow = useMediaQuery("(max-width: 1023px)");

  const [view, setView] = useState<View>("week");
  const [anchorDate, setAnchorDate] = useState(() => new Date());
  const [scheduleDrawerDate, setScheduleDrawerDate] = useState<string | null>(null);
  const [peek, setPeek] = useState<{ session: TrainerCalendarSessionResponse; anchor: HTMLElement } | null>(null);
  /* Empty set = every client shown (decision: default to "all clients", track exclusions
   * instead of inclusions so no async client-list load is needed to initialize it). */
  const [deselectedClientIds, setDeselectedClientIds] = useState<Set<number>>(new Set());
  /* Cancelled occurrences are hidden by default (decision #7 in the design doc). */
  const [showCancelled, setShowCancelled] = useState(false);

  const clientsQ = useQuery({
    queryKey: queryKeys.trainerClients.all(),
    queryFn: trainerApi.clients,
  });
  const clients = clientsQ.data;
  const noClients = clientsQ.isSuccess && clientsQ.data.length === 0;

  const weekStart = startOfWeek(anchorDate, { weekStartsOn: 1 });
  const weekEnd = addDays(weekStart, 6);

  const monthStart = startOfMonth(anchorDate);
  const monthEnd = endOfMonth(anchorDate);
  const monthGridStart = startOfWeek(monthStart, { weekStartsOn: 1 });
  const monthGridEnd = endOfWeek(monthEnd, { weekStartsOn: 1 });

  /* The whole displayed period has already passed (not just "today is later in
   * the week than Monday") — scheduling only allows a start date of today or later. */
  const isPastPeriod = isBefore(view === "week" ? weekEnd : monthEnd, startOfDay(new Date()));

  const rangeStart = view === "week" ? weekStart : monthGridStart;
  const rangeEnd = view === "week" ? weekEnd : monthGridEnd;
  const from = format(rangeStart, "yyyy-MM-dd");
  const to = format(rangeEnd, "yyyy-MM-dd");

  const { data: sessions, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerCalendar.range(from, to),
    queryFn: () => trainerApi.calendarSessions(from, to),
  });
  const visibleSessions = (sessions ?? []).filter(
    (s) => (showCancelled || s.status !== "CANCELLED") && !deselectedClientIds.has(s.clientId),
  );

  const toggleClient = (clientId: number) => {
    setDeselectedClientIds((prev) => {
      const next = new Set(prev);
      if (next.has(clientId)) next.delete(clientId);
      else next.add(clientId);
      return next;
    });
  };
  const toggleAllClients = () => {
    setDeselectedClientIds((prev) => (prev.size === 0 ? new Set((clients ?? []).map((c) => c.clientId)) : new Set()));
  };

  const periodLabel =
    view === "week"
      ? formatWeekRange(weekStart, weekEnd, dateLocale)
      : locale === "hu"
        ? format(anchorDate, "yyyy. MMMM", { locale: dateLocale })
        : format(anchorDate, "MMMM yyyy", { locale: dateLocale });

  const goToday = () => setAnchorDate(new Date());
  const goPrev = () => setAnchorDate((d) => (view === "week" ? addWeeks(d, -1) : addMonths(d, -1)));
  const goNext = () => setAnchorDate((d) => (view === "week" ? addWeeks(d, 1) : addMonths(d, 1)));
  /* Toolbar CTA — always defaults to today, regardless of which week/month is displayed. */
  const openScheduleDrawer = () => setScheduleDrawerDate(format(new Date(), "yyyy-MM-dd"));

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
        {clients && clients.length > 0 && (
          <CalendarClientFilter
            clients={clients}
            deselectedClientIds={deselectedClientIds}
            onToggleClient={toggleClient}
            onToggleAll={toggleAllClients}
          />
        )}
        <Switch checked={showCancelled} onChange={setShowCancelled} label={t("showCancelled")} />
        <button
          onClick={openScheduleDrawer}
          disabled={isPastPeriod}
          className="flex items-center gap-1.5 rounded-2xl px-3.5 py-2 text-[12.5px] font-extrabold disabled:cursor-not-allowed"
          style={{
            background: isPastPeriod ? "var(--surface-highest)" : "var(--tertiary)",
            color: isPastPeriod ? "var(--on-surface-variant)" : "#161611",
          }}
        >
          <span className="material-symbols-rounded text-lg">add</span>
          {tSchedule("scheduleWorkout")}
        </button>
      </div>

      {noClients ? (
        <div className="rounded-2xl p-8 text-center" style={{ background: "var(--surface)" }}>
          <div
            className="w-[58px] h-[58px] rounded-[18px] flex items-center justify-center mx-auto mb-3"
            style={{ background: "var(--surface-container)", color: "var(--tertiary)" }}
          >
            <span className="material-symbols-rounded text-3xl">group</span>
          </div>
          <p className="text-[15px] font-extrabold" style={{ color: "var(--on-surface)" }}>
            {tDashboard("noClientsTitle")}
          </p>
          <p className="text-xs mt-1" style={{ color: "var(--on-surface-variant)" }}>
            {tDashboard("noClientsBody")}
          </p>
          <Link
            href="/admin/invites"
            className="inline-flex items-center gap-2 rounded-2xl px-4.5 py-2.5 text-[13px] font-extrabold mt-4"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            <span className="material-symbols-rounded text-lg">person_add</span>
            {tDashboard("inviteFirst")}
          </Link>
        </div>
      ) : isLoading ? (
        view === "week" ? (
          narrow ? <CalendarAgendaSkeleton /> : <CalendarWeekSkeleton />
        ) : (
          <CalendarMonthSkeleton />
        )
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : visibleSessions.length === 0 ? (
        <EmptyState
          icon="calendar_month"
          title={t("emptyTitle")}
          body={t("emptyBody")}
          action={
            isPastPeriod ? undefined : (
              <button
                onClick={openScheduleDrawer}
                className="flex items-center gap-1.5 rounded-2xl px-4 py-2.5 text-[13px] font-extrabold"
                style={{ background: "var(--tertiary)", color: "#161611" }}
              >
                <span className="material-symbols-rounded text-lg">add</span>
                {tSchedule("scheduleWorkout")}
              </button>
            )
          }
        />
      ) : view === "week" ? (
        narrow ? (
          <CalendarAgendaView
            weekStart={weekStart}
            sessions={visibleSessions}
            onSelectSession={(session, anchor) => setPeek({ session, anchor })}
          />
        ) : (
          <CalendarWeekView
            weekStart={weekStart}
            sessions={visibleSessions}
            onScheduleDay={setScheduleDrawerDate}
            onSelectSession={(session, anchor) => setPeek({ session, anchor })}
          />
        )
      ) : (
        <CalendarMonthView
          monthAnchor={anchorDate}
          sessions={visibleSessions}
          compact={narrow}
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
