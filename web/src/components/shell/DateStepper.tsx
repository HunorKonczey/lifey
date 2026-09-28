"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { addDays, subDays } from "date-fns";
import { Icon } from "@/components/ds/Icon";
import { IconButton } from "@/components/ds/IconButton";
import { Popover } from "@/components/ds/Popover";
import { CalendarPopover } from "@/components/ds/date/CalendarPopover";
import { isSameDay } from "@/components/ds/date/monthGrid";
import { useFormat } from "@/lib/format/useFormat";
import { useDateStore } from "@/lib/hooks/useDateStore";

function isTypingTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  return target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable;
}

/**
 * DS-02's top-bar date stepper (D-W0.21): 40px round ‹›, a centre pill
 * ("Ma" 15/700 + the full weekday date 14/600, or just the date on any other
 * day), a "Back to today" chip once pinned to a day, next disabled on today,
 * and a `CalendarPopover` on the pill. ←/→/T when no field has focus.
 */
export function DateStepper() {
  const common = useTranslations("common");
  const fmt = useFormat();
  const { date, setDate } = useDateStore();
  const pillRef = useRef<HTMLButtonElement>(null);
  const [calendarOpen, setCalendarOpen] = useState(false);

  const today = new Date();
  const isToday = isSameDay(date, today);
  const label = fmt.dayLabel(date, today);
  const [primary, secondary] = isToday ? (label.split(" · ") as [string, string]) : [null, label];

  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if (isTypingTarget(e.target)) return;
      if (e.key === "ArrowLeft") setDate(subDays(date, 1));
      else if (e.key === "ArrowRight") setDate(addDays(date, 1));
      else if (e.key.toLowerCase() === "t") setDate(new Date());
      else return;
      e.preventDefault();
    }
    document.addEventListener("keydown", handleKey);
    return () => document.removeEventListener("keydown", handleKey);
  }, [date, setDate]);

  return (
    <div className="flex items-center gap-2">
      <IconButton
        icon="chevron_left"
        label={common("previousDay")}
        shortcut="←"
        size={40}
        style={{ borderRadius: "var(--r-pill)" }}
        onClick={() => setDate(subDays(date, 1))}
      />

      <button
        ref={pillRef}
        type="button"
        onClick={() => setCalendarOpen((v) => !v)}
        aria-haspopup="dialog"
        aria-expanded={calendarOpen}
        className="lifey-button flex items-center gap-2 px-4 h-10 rounded-[var(--r-pill)]"
        style={{ background: "var(--nested)" }}
      >
        <Icon name="calendar_today" size={18} color="var(--text-2)" />
        {primary ? (
          <span className="whitespace-nowrap">
            <span style={{ fontSize: 15, fontWeight: 700 }}>{primary}</span>
            <span style={{ fontSize: 14, fontWeight: 600, color: "var(--text-2)" }}> · {secondary}</span>
          </span>
        ) : (
          <span className="whitespace-nowrap" style={{ fontSize: 15, fontWeight: 700 }}>
            {secondary}
          </span>
        )}
      </button>

      {!isToday && (
        <button
          type="button"
          onClick={() => setDate(new Date())}
          className="lifey-button px-3 h-8 rounded-[var(--r-pill)] type-body-s whitespace-nowrap"
          style={{ background: "var(--primary-tint)", color: "var(--on-primary-tint)" }}
        >
          {common("backToToday")}
        </button>
      )}

      <IconButton
        icon="chevron_right"
        label={common("nextDay")}
        shortcut="→"
        size={40}
        disabled={isToday}
        style={{ borderRadius: "var(--r-pill)", opacity: isToday ? 0.4 : 1 }}
        onClick={() => setDate(addDays(date, 1))}
      />

      <Popover open={calendarOpen} onClose={() => setCalendarOpen(false)} anchorRef={pillRef} width={300}>
        <div className="p-3">
          <CalendarPopover
            value={date}
            onChange={(d) => {
              setDate(d);
              setCalendarOpen(false);
            }}
            disableFuture
          />
        </div>
      </Popover>
    </div>
  );
}
