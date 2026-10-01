"use client";

import { useCallback, useMemo, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { addDays, addMonths, addWeeks, endOfMonth, endOfWeek, format, isBefore, startOfDay, startOfMonth, startOfWeek } from "date-fns";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useTopBarCentre } from "@/lib/hooks/useTopBarSlot";
import { Button, Icon, IconButton, SegmentedControl, Switch } from "@/components/ds";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { CalendarWeekView } from "./CalendarWeekView";
import { CalendarMonthView } from "./CalendarMonthView";
import { CalendarAgendaView } from "./CalendarAgendaView";
import { CalendarWeekSkeleton, CalendarMonthSkeleton, CalendarAgendaSkeleton } from "./CalendarSkeleton";
import { CalendarSessionPeek } from "./CalendarSessionPeek";
import { CalendarClientFilter } from "./CalendarClientFilter";
import { clientDisplayName } from "./ClientAvatar";
import { ScheduleWorkoutDrawer } from "./ScheduleWorkoutDrawer";
import type { TrainerCalendarSessionResponse } from "../types";

type View = "day" | "week" | "month";

/**
 * The trainer calendar (W8-A): every active client's scheduled workouts in one view. The period navigator ("‹ szept.
 * 22–28., 2026 ›" and "Ma") sits in the top bar's centre; the header row carries Nap · Hét · Hónap, the client filter,
 * the cancelled switch and the primary "Ütemezés". "Nap" is one column of the week grid.
 */
export function TrainerCalendar() {
  const t = useTranslations("admin.calendar");
  const tDashboard = useTranslations("admin.dashboard");
  const tSchedule = useTranslations("admin.schedule");
  const fmt = useFormat();
  const phone = useMediaQuery("(max-width: 767px)");
  /* Below the desktop width the 7-column grid does not fit: the week becomes an agenda list, the month dots. */
  const narrow = useMediaQuery("(max-width: 1023px)");

  const [view, setView] = useState<View>("week");
  const [anchorDate, setAnchorDate] = useState(() => new Date());
  const [slot, setSlot] = useState<{ date: string; time: string | null } | null>(null);
  const [peek, setPeek] = useState<{ session: TrainerCalendarSessionResponse; anchor: HTMLElement } | null>(null);
  /* Empty set = every client shown: exclusions are tracked, not inclusions, so no async client list is needed to initialise it. */
  const [deselectedClientIds, setDeselectedClientIds] = useState<Set<number>>(new Set());
  /* Cancelled occurrences are hidden by default (decision #7 in the design doc). */
  const [showCancelled, setShowCancelled] = useState(false);

  const clientsQ = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });
  const clients = clientsQ.data;
  const noClients = clientsQ.isSuccess && clientsQ.data.length === 0;
  const names = useMemo(() => new Map((clients ?? []).map((c) => [c.clientId, clientDisplayName(c)])), [clients]);

  const weekStart = startOfWeek(anchorDate, { weekStartsOn: 1 });
  const weekEnd = addDays(weekStart, 6);
  const monthStart = startOfMonth(anchorDate);
  const monthEnd = endOfMonth(anchorDate);
  const monthGridStart = startOfWeek(monthStart, { weekStartsOn: 1 });
  const monthGridEnd = endOfWeek(monthEnd, { weekStartsOn: 1 });

  const periodEnd = view === "month" ? monthEnd : view === "day" ? anchorDate : weekEnd;
  /* The whole displayed period has passed — scheduling only allows a start date of today or later. */
  const isPastPeriod = isBefore(periodEnd, startOfDay(new Date()));

  const from = format(view === "month" ? monthGridStart : weekStart, "yyyy-MM-dd");
  const to = format(view === "month" ? monthGridEnd : weekEnd, "yyyy-MM-dd");

  const { data: sessions, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerCalendar.range(from, to),
    queryFn: () => trainerApi.calendarSessions(from, to),
  });
  const visibleSessions = (sessions ?? []).filter((s) => (showCancelled || s.status !== "CANCELLED") && !deselectedClientIds.has(s.clientId));
  const daySessions = view === "day" ? visibleSessions.filter((s) => s.scheduledFor === format(anchorDate, "yyyy-MM-dd")) : visibleSessions;

  const toggleClient = (clientId: number) => {
    setDeselectedClientIds((prev) => {
      const next = new Set(prev);
      if (next.has(clientId)) next.delete(clientId);
      else next.add(clientId);
      return next;
    });
  };
  const toggleAllClients = () => setDeselectedClientIds((prev) => (prev.size === 0 ? new Set((clients ?? []).map((c) => c.clientId)) : new Set()));

  const periodLabel =
    view === "week"
      ? `${fmt.dateRange(weekStart, weekEnd)}, ${weekStart.getFullYear()}`
      : view === "day"
        ? fmt.longDate(anchorDate)
        : fmt.monthYear(anchorDate);

  const step = useCallback(
    (dir: 1 | -1) => setAnchorDate((d) => (view === "month" ? addMonths(d, dir) : view === "day" ? addDays(d, dir) : addWeeks(d, dir))),
    [view],
  );
  const prevLabel = view === "month" ? t("previousMonth") : view === "day" ? t("previousDay") : t("previousWeek");
  const nextLabel = view === "month" ? t("nextMonth") : view === "day" ? t("nextDay") : t("nextWeek");
  const todayLabel = t("today");

  const navNode = useMemo(
    () => (
      <div className="flex items-center gap-1.5">
        <Button variant="secondary" onClick={() => setAnchorDate(new Date())}>{todayLabel}</Button>
        <IconButton icon="chevron_left" label={prevLabel} onClick={() => step(-1)} />
        <span className="type-body px-1 whitespace-nowrap" style={{ fontWeight: 800 }} aria-live="polite">{periodLabel}</span>
        <IconButton icon="chevron_right" label={nextLabel} onClick={() => step(1)} />
      </div>
    ),
    [todayLabel, prevLabel, nextLabel, periodLabel, step],
  );
  useTopBarCentre(phone ? null : navNode);

  /* Toolbar CTA — always defaults to today, whatever period is displayed. */
  const openSchedule = () => setSlot({ date: format(new Date(), "yyyy-MM-dd"), time: null });

  const days = view === "day" ? [anchorDate] : Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));

  return (
    <div className="flex flex-col gap-4">
      {phone && <div className="flex justify-center">{navNode}</div>}
      <div className="flex flex-wrap items-center gap-3">
        <SegmentedControl<View>
          aria-label={t("viewAria")}
          size="sm"
          value={view}
          onChange={setView}
          options={[
            { value: "day", label: t("day") },
            { value: "week", label: t("week") },
            { value: "month", label: t("month") },
          ]}
        />
        {clients && clients.length > 0 && (
          <CalendarClientFilter clients={clients} deselectedClientIds={deselectedClientIds} onToggleClient={toggleClient} onToggleAll={toggleAllClients} />
        )}
        <Switch checked={showCancelled} onChange={setShowCancelled} label={t("showCancelled")} />
        <div className="flex-1" />
        <Button onClick={openSchedule} disabled={isPastPeriod}>
          <Icon name="add" size={20} />
          {tSchedule("scheduleWorkout")}
        </Button>
      </div>

      {noClients ? (
        <div className="flex flex-col items-center gap-3 p-10 text-center" style={{ borderRadius: "var(--r-card)", background: "var(--card)" }}>
          <Icon name="group" size={36} color="var(--text-3)" />
          <p style={{ fontSize: 18, fontWeight: 800 }}>{tDashboard("noClientsTitle")}</p>
          <p className="type-body" style={{ color: "var(--text-2)" }}>{tDashboard("noClientsBody")}</p>
          <Link href="/admin/invites">
            <Button>
              <Icon name="person_add" size={20} />
              {tDashboard("inviteFirst")}
            </Button>
          </Link>
        </div>
      ) : isLoading ? (
        view === "month" ? <CalendarMonthSkeleton /> : narrow && view === "week" ? <CalendarAgendaSkeleton /> : <CalendarWeekSkeleton />
      ) : isError ? (
        <ErrorState onRetry={() => refetch()} />
      ) : view === "month" ? (
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
      ) : view === "week" && narrow ? (
        visibleSessions.length === 0 ? (
          <EmptyState icon="calendar_month" title={t("emptyTitle")} body={t("emptyBody")} />
        ) : (
          <CalendarAgendaView weekStart={weekStart} sessions={visibleSessions} onSelectSession={(session, anchor) => setPeek({ session, anchor })} />
        )
      ) : (
        <>
          <CalendarWeekView
            days={days}
            sessions={daySessions}
            names={names}
            onScheduleSlot={(date, time) => setSlot({ date, time })}
            onSelectSession={(session, anchor) => setPeek({ session, anchor })}
          />
          <ul className="flex flex-wrap items-center gap-x-5 gap-y-1 type-body-s" style={{ color: "var(--text-2)" }} aria-label={t("legendAria")}>
            {([["var(--primary)", "UPCOMING"], ["var(--metric-protein)", "DONE"], ["var(--heart)", "MISSED"]] as const).map(([color, status]) => (
              <li key={status} className="inline-flex items-center gap-1.5">
                <span aria-hidden style={{ width: 10, height: 10, borderRadius: 3, background: color }} />
                {tSchedule(`status.${status}`)}
              </li>
            ))}
          </ul>
        </>
      )}

      {slot && (
        <ScheduleWorkoutDrawer
          initialStartDate={slot.date}
          initialTimeOfDay={slot.time ?? undefined}
          onClose={() => setSlot(null)}
        />
      )}

      {peek && <CalendarSessionPeek key={peek.session.sessionId} session={peek.session} anchorEl={peek.anchor} clientName={names.get(peek.session.clientId)} onClose={() => setPeek(null)} />}
    </div>
  );
}
