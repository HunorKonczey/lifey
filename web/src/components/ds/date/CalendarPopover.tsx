"use client";

import { useRef, useState, type KeyboardEvent } from "react";
import { useLocale } from "next-intl";
import { createFormat } from "@/lib/format/lifeyFormat";
import { IconButton } from "../IconButton";
import { isFuture, isSameDay, monthGrid } from "./monthGrid";

export interface CalendarPopoverProps {
  value: Date;
  onChange: (date: Date) => void;
  today?: Date;
  /** Future days are muted and unselectable (D-W0.10). */
  disableFuture?: boolean;
  /** A dot under any day this returns true for — "has a logged meal", etc. */
  hasData?: (date: Date) => boolean;
  className?: string;
}

/**
 * Month grid, Monday-first (D-W0.10): today filled primary, the selection a
 * primary ring, data dots via `hasData`, future days muted when
 * `disableFuture`. Arrow keys move a day at a time (a roving focus cursor,
 * not yet a selection — Enter/Space commits it), ↑/↓ a week,
 * PageUp/PageDown a month.
 */
export function CalendarPopover({ value, onChange, today = new Date(), disableFuture = false, hasData, className }: CalendarPopoverProps) {
  const locale = useLocale();
  const format = createFormat(locale);
  const [viewDate, setViewDate] = useState(new Date(value.getFullYear(), value.getMonth(), 1));
  const [focusedDate, setFocusedDate] = useState(value);
  const cellRefs = useRef(new Map<string, HTMLButtonElement>());

  const grid = monthGrid(viewDate.getFullYear(), viewDate.getMonth());
  const monthLabel = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" }).format(viewDate);
  const weekdayLabels = grid.slice(0, 7).map((d) => format.weekdayShort(d.date));

  function focusDate(next: Date) {
    setFocusedDate(next);
    if (next.getMonth() !== viewDate.getMonth() || next.getFullYear() !== viewDate.getFullYear()) {
      setViewDate(new Date(next.getFullYear(), next.getMonth(), 1));
    }
    requestAnimationFrame(() => cellRefs.current.get(next.toDateString())?.focus());
  }

  function moveFocusByDays(days: number) {
    const next = new Date(focusedDate);
    next.setDate(next.getDate() + days);
    focusDate(next);
  }

  function moveFocusByMonths(months: number) {
    focusDate(new Date(focusedDate.getFullYear(), focusedDate.getMonth() + months, focusedDate.getDate()));
  }

  function selectIfAllowed(date: Date) {
    if (disableFuture && isFuture(date, today)) return;
    onChange(date);
  }

  function handleKeyDown(e: KeyboardEvent<HTMLDivElement>) {
    const handlers: Record<string, () => void> = {
      ArrowLeft: () => moveFocusByDays(-1),
      ArrowRight: () => moveFocusByDays(1),
      ArrowUp: () => moveFocusByDays(-7),
      ArrowDown: () => moveFocusByDays(7),
      PageUp: () => moveFocusByMonths(-1),
      PageDown: () => moveFocusByMonths(1),
      Enter: () => selectIfAllowed(focusedDate),
      " ": () => selectIfAllowed(focusedDate),
    };
    const handler = handlers[e.key];
    if (!handler) return;
    e.preventDefault();
    handler();
  }

  return (
    <div className={className} role="dialog" aria-label={monthLabel} style={{ width: 300 }}>
      <div className="flex items-center justify-between mb-2">
        <IconButton icon="chevron_left" label="Previous month" size={32} onClick={() => moveFocusByMonths(-1)} />
        <span className="type-title-s capitalize">{monthLabel}</span>
        <IconButton icon="chevron_right" label="Next month" size={32} onClick={() => moveFocusByMonths(1)} />
      </div>
      <div className="grid grid-cols-7 gap-1 mb-1">
        {weekdayLabels.map((label, i) => (
          <span key={i} className="type-label text-center" style={{ color: "var(--text-3)" }}>
            {label}
          </span>
        ))}
      </div>
      <div role="grid" aria-label={monthLabel} className="grid grid-cols-7 gap-1" onKeyDown={handleKeyDown}>
        {Array.from({ length: 6 }, (_, week) => (
          // display:contents — a real `role="row"` for the ARIA grid
          // structure (axe: aria-required-children/parent) without
          // interrupting the outer grid-cols-7 layout, which needs its
          // cells as direct grid-item children.
          <div key={week} role="row" style={{ display: "contents" }}>
            {grid.slice(week * 7, week * 7 + 7).map(({ date, inMonth }) => {
              const disabled = disableFuture && isFuture(date, today);
              const today_ = isSameDay(date, today);
              const selected = isSameDay(date, value);
              const focusable = isSameDay(date, focusedDate);
              const muted = !inMonth || disabled;
              return (
                <button
                  key={date.toISOString()}
                  ref={(el) => {
                    if (el) cellRefs.current.set(date.toDateString(), el);
                  }}
                  type="button"
                  role="gridcell"
                  tabIndex={focusable ? 0 : -1}
                  disabled={disabled}
                  aria-current={today_ ? "date" : undefined}
                  aria-selected={selected}
                  aria-label={format.longDate(date)}
                  onClick={() => selectIfAllowed(date)}
                  className="relative aspect-square rounded-[var(--r-control)] type-body-s tabular"
                  style={{
                    // A dimmer text colour, not opacity — opacity fades the
                    // background too, and axe caught that dropping a muted
                    // day's contrast below AA (dark and light both).
                    color: today_ ? "var(--on-primary)" : muted ? "var(--text-3)" : "var(--text)",
                    background: today_ ? "var(--primary)" : "transparent",
                    boxShadow: selected && !today_ ? "inset 0 0 0 2px var(--primary), var(--shadow-focus)" : "var(--shadow-focus)",
                  }}
                >
                  {date.getDate()}
                  {hasData?.(date) && (
                    <span
                      className="absolute bottom-1 left-1/2 -translate-x-1/2 w-1 h-1 rounded-full"
                      style={{ background: today_ ? "var(--on-primary)" : "var(--primary)" }}
                    />
                  )}
                </button>
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
}
