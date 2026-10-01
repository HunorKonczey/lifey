"use client";

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { DndContext, DragOverlay, PointerSensor, pointerWithin, useDraggable, useDroppable, useSensor, useSensors, type DragEndEvent, type DragStartEvent } from "@dnd-kit/core";
import { useTranslations } from "next-intl";
import { format, isBefore, isSameDay, startOfDay } from "date-fns";
import { Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { bucketSessions, buildHourRows, dropAction, gapKey, occupiedHours, slotKey, type DropSlot } from "../calendarGrid";
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
  /** An upcoming event was dropped on another slot: move it, or — with Shift held — copy it there. */
  onDropSession?: (session: TrainerCalendarSessionResponse, slot: DropSlot, copy: boolean) => void;
}

/**
 * The week as a real grid (W8-A): days as columns, hours as rows, today's column tinted and its header a pill. Runs of
 * empty hours fold into one "⤢ 10:00–15:00 · nincs esemény · kinyitás" row; sessions without a time sit in a "no time"
 * row on top; every event is a card with a status bar *and* the status in words, never colour alone. Clicking an empty
 * cell asks for a workout at that day and hour; an upcoming event can be dragged to another slot (W8.5b) — moved, or
 * copied while Shift is held.
 */
export function CalendarWeekView({ days, sessions, names, onScheduleSlot, onSelectSession, onDropSession }: CalendarWeekViewProps) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const fmt = useFormat();
  const today = startOfDay(new Date());
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [dragging, setDragging] = useState<TrainerCalendarSessionResponse | null>(null);
  const [copying, setCopying] = useState(false);
  const shift = useRef(false);

  // Shift is read at the moment of the drop, so it can be pressed or released mid-drag; the overlay says which it will be.
  useEffect(() => {
    const sync = (e: KeyboardEvent | PointerEvent) => {
      shift.current = e.shiftKey;
      setCopying(e.shiftKey);
    };
    window.addEventListener("keydown", sync);
    window.addEventListener("keyup", sync);
    window.addEventListener("pointermove", sync);
    return () => {
      window.removeEventListener("keydown", sync);
      window.removeEventListener("keyup", sync);
      window.removeEventListener("pointermove", sync);
    };
  }, []);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));
  const { cells, untimed } = useMemo(() => bucketSessions(sessions), [sessions]);
  const rows = useMemo(() => buildHourRows(occupiedHours(sessions), { expanded }), [sessions, expanded]);
  const hasUntimed = untimed.size > 0;
  const hourLabel = (h: number) => fmt.time(new Date(2000, 0, 1, h));
  const cols = `64px repeat(${days.length}, minmax(0, 1fr))`;
  const pad = (h: number) => `${String(h).padStart(2, "0")}:00`;
  const nameOf = (s: TrainerCalendarSessionResponse) => names?.get(s.clientId) ?? nameFor(s.clientEmail);

  const onDragStart = (e: DragStartEvent) => setDragging((e.active.data.current as { session: TrainerCalendarSessionResponse } | undefined)?.session ?? null);
  const onDragEnd = (e: DragEndEvent) => {
    const session = (e.active.data.current as { session: TrainerCalendarSessionResponse } | undefined)?.session;
    const slot = e.over?.data.current as DropSlot | undefined;
    setDragging(null);
    if (!session || !slot || !onDropSession) return;
    const copy = shift.current;
    // Moving onto where it already is does nothing; copying onto it is still a (second) workout there.
    if (!copy && dropAction(session, slot) === "noop") return;
    onDropSession(session, slot, copy);
  };

  const card = (s: TrainerCalendarSessionResponse) => (
    <EventCard key={s.sessionId} session={s} name={nameOf(s)} statusLabel={tSchedule(`status.${s.status}`)} unnamed={tSchedule("unnamedTemplate")} draggable={!!onDropSession && s.status === "UPCOMING"} onSelect={onSelectSession} />
  );

  return (
    <DndContext sensors={sensors} collisionDetection={pointerWithin} onDragStart={onDragStart} onDragEnd={onDragEnd} onDragCancel={() => setDragging(null)}>
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
                  <SlotCell key={iso} slot={{ date: iso, time: null }} today={isSameDay(day, today)} droppable={!!onDropSession && !isBefore(day, today)}>
                    {(untimed.get(iso) ?? []).map(card)}
                  </SlotCell>
                );
              })}
            </div>
          )}

          {rows.map((row) => {
            if (row.kind === "gap") {
              return (
                <div key={`gap-${row.from}`} role="row" style={{ borderTop: "1px solid var(--hairline)" }}>
                  <div role="gridcell" aria-colspan={days.length + 1}>
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
                    <SlotCell key={iso} slot={{ date: iso, time: pad(row.hour) }} today={isSameDay(day, today)} droppable={!!onDropSession && !past}>
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
                    </SlotCell>
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>

      <DragOverlay dropAnimation={null}>
        {dragging && (
          <div className="flex flex-col py-1.5 pl-3 pr-3" style={{ borderRadius: 10, background: "var(--card)", boxShadow: "var(--e2), inset 0 0 0 2px var(--primary)", minWidth: 160 }}>
            <span style={{ fontSize: 13, fontWeight: 700 }}>{nameOf(dragging)}</span>
            <span style={{ fontSize: 12, fontWeight: 600, color: "var(--text-2)" }}>
              {copying ? t("dragCopy") : t("dragMove")} · {dragging.templateName ?? tSchedule("unnamedTemplate")}
            </span>
          </div>
        )}
      </DragOverlay>
    </DndContext>
  );
}

/**
 * One slot of the grid — a day and an hour (or the "no time" row) — as a drop target: while an event is over it the
 * cell gets a 2 px primary ring. The stacking of several events in one cell is unchanged.
 */
function SlotCell({ slot, today, droppable, children }: { slot: DropSlot; today: boolean; droppable: boolean; children: ReactNode }) {
  const { setNodeRef, isOver } = useDroppable({ id: `slot-${slotKey(slot)}`, data: slot, disabled: !droppable });
  return (
    <div
      ref={setNodeRef}
      role="gridcell"
      className="group relative flex flex-col gap-1 p-1 min-w-0"
      style={{ background: isOver ? "var(--primary-tint)" : today ? "color-mix(in srgb, var(--primary) 4%, transparent)" : undefined, boxShadow: isOver ? "inset 0 0 0 2px var(--primary)" : undefined }}
    >
      {children}
    </div>
  );
}

/** An event card: a button (opens the peek) that is also a drag source — pointer only, so Enter and Space still click it. */
function EventCard({ session: s, name, statusLabel, unnamed, draggable, onSelect }: { session: TrainerCalendarSessionResponse; name: string; statusLabel: string; unnamed: string; draggable: boolean; onSelect: (s: TrainerCalendarSessionResponse, el: HTMLElement) => void }) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({ id: `event-${s.sessionId}`, data: { session: s }, disabled: !draggable });
  const cancelled = s.status === "CANCELLED";
  return (
    <button
      ref={setNodeRef}
      type="button"
      onClick={(e) => onSelect(s, e.currentTarget)}
      onPointerDown={draggable ? (listeners?.onPointerDown as React.PointerEventHandler<HTMLButtonElement> | undefined) : undefined}
      {...(draggable ? { "aria-roledescription": attributes["aria-roledescription"] } : {})}
      data-testid="calendar-session-card"
      data-client-email={s.clientEmail}
      className="lifey-button relative z-10 flex flex-col text-left min-w-0 py-1.5 pl-3 pr-2 touch-manipulation"
      style={{ borderRadius: 10, background: "var(--nested)", opacity: isDragging ? 0.4 : cancelled ? 0.6 : 1, cursor: draggable ? "grab" : undefined }}
    >
      <span aria-hidden className="absolute left-0 top-1.5 bottom-1.5" style={{ width: 3, borderRadius: 2, background: BAR[s.status] }} />
      <span className="truncate" style={{ fontSize: 13, fontWeight: 700, textDecoration: cancelled ? "line-through" : "none" }}>{name}</span>
      <span className="truncate" style={{ fontSize: 12, fontWeight: 600, color: "var(--text-2)" }}>
        {s.templateName ?? unnamed} · {statusLabel}
      </span>
    </button>
  );
}
