"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  addMonths,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isAfter,
  isBefore,
  isSameDay,
  isSameMonth,
  isValid,
  parseISO,
  setMonth,
  setYear,
  startOfMonth,
  startOfWeek,
  subMonths,
} from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { useTranslations } from "next-intl";
import { useLocale } from "@/lib/hooks/useLocale";

const DATE_LOCALES = { en: enUS, hu } as const;

interface DatePickerProps {
  /** ISO "yyyy-MM-dd", or "" when unset. */
  value: string;
  onChange: (value: string) => void;
  min?: Date;
  max?: Date;
  placeholder?: string;
  hasError?: boolean;
  id?: string;
}

/** Calendar-dropdown date picker matching the app's input styling. Native
 *  `<input type="date">` renders inconsistently across browsers and offers
 *  no way to constrain the visible range beyond min/max attributes users
 *  can still type past. */
export function DatePicker({ value, onChange, min, max, placeholder, hasError, id }: DatePickerProps) {
  const t = useTranslations("common");
  const locale = useLocale((s) => s.locale);
  const dateLocale = DATE_LOCALES[locale];

  const parsed = value ? parseISO(value) : undefined;
  const selected = parsed && isValid(parsed) ? parsed : undefined;

  const [open, setOpen] = useState(false);
  const [viewDate, setViewDate] = useState(selected ?? max ?? new Date());
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (selected) setViewDate(selected);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);

  useEffect(() => {
    if (!open) return;
    function handleClick(e: MouseEvent) {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    }
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("mousedown", handleClick);
    document.addEventListener("keydown", handleKey);
    return () => {
      document.removeEventListener("mousedown", handleClick);
      document.removeEventListener("keydown", handleKey);
    };
  }, [open]);

  const weeks = useMemo(() => {
    const start = startOfWeek(startOfMonth(viewDate), { weekStartsOn: 1 });
    const end = endOfWeek(endOfMonth(viewDate), { weekStartsOn: 1 });
    const days = eachDayOfInterval({ start, end });
    const rows: Date[][] = [];
    for (let i = 0; i < days.length; i += 7) rows.push(days.slice(i, i + 7));
    return rows;
  }, [viewDate]);

  const weekdayLabels = useMemo(() => {
    const start = startOfWeek(new Date(), { weekStartsOn: 1 });
    return eachDayOfInterval({ start, end: endOfWeek(start, { weekStartsOn: 1 }) }).map((d) =>
      format(d, "EEEEEE", { locale: dateLocale }),
    );
  }, [dateLocale]);

  const monthLabels = useMemo(
    () => Array.from({ length: 12 }, (_, i) => format(setMonth(new Date(), i), "LLLL", { locale: dateLocale })),
    [dateLocale],
  );

  const yearOptions = useMemo(() => {
    const maxYear = (max ?? new Date()).getFullYear();
    const minYear = min ? min.getFullYear() : maxYear - 120;
    const years: number[] = [];
    for (let y = maxYear; y >= minYear; y--) years.push(y);
    return years;
  }, [min, max]);

  const prevMonthDisabled = min ? isBefore(endOfMonth(subMonths(viewDate, 1)), min) : false;
  const nextMonthDisabled = max ? isAfter(startOfMonth(addMonths(viewDate, 1)), max) : false;

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        id={id}
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-2 justify-between px-3 h-11 rounded-[var(--r-input)] text-sm tabular w-full"
        style={{
          background: "var(--surface-container)",
          border: `1px solid ${hasError ? "var(--error)" : "var(--outline)"}`,
        }}
      >
        <span style={{ color: selected ? "var(--on-surface)" : "var(--on-surface-variant)" }}>
          {selected ? format(selected, "PP", { locale: dateLocale }) : (placeholder ?? t("selectDate"))}
        </span>
        <span className="material-symbols-rounded text-lg" style={{ color: "var(--on-surface-variant)" }}>
          calendar_month
        </span>
      </button>

      {open && (
        <div
          className="absolute z-20 mt-2 p-3 rounded-[var(--r-card)] shadow-lg w-72"
          style={{ background: "var(--surface-high)", border: "1px solid var(--outline)" }}
        >
          <div className="flex items-center justify-between mb-2">
            <button
              type="button"
              onClick={() => setViewDate((d) => subMonths(d, 1))}
              disabled={prevMonthDisabled}
              aria-label={t("previousMonth")}
              className="w-8 h-8 flex items-center justify-center rounded-full transition-opacity disabled:opacity-30"
              style={{ color: "var(--on-surface-variant)" }}
            >
              <span className="material-symbols-rounded text-xl">chevron_left</span>
            </button>

            <div className="flex items-center gap-1">
              <select
                value={viewDate.getMonth()}
                onChange={(e) => setViewDate((d) => setMonth(d, Number(e.target.value)))}
                className="bg-transparent text-sm font-semibold outline-none"
                style={{ color: "var(--on-surface)" }}
              >
                {monthLabels.map((label, i) => (
                  <option key={label} value={i} style={{ background: "var(--surface-high)" }}>
                    {label}
                  </option>
                ))}
              </select>
              <select
                value={viewDate.getFullYear()}
                onChange={(e) => setViewDate((d) => setYear(d, Number(e.target.value)))}
                className="bg-transparent text-sm font-semibold outline-none"
                style={{ color: "var(--on-surface)" }}
              >
                {yearOptions.map((y) => (
                  <option key={y} value={y} style={{ background: "var(--surface-high)" }}>
                    {y}
                  </option>
                ))}
              </select>
            </div>

            <button
              type="button"
              onClick={() => setViewDate((d) => addMonths(d, 1))}
              disabled={nextMonthDisabled}
              aria-label={t("nextMonth")}
              className="w-8 h-8 flex items-center justify-center rounded-full transition-opacity disabled:opacity-30"
              style={{ color: "var(--on-surface-variant)" }}
            >
              <span className="material-symbols-rounded text-xl">chevron_right</span>
            </button>
          </div>

          <div className="grid grid-cols-7 gap-1 mb-1">
            {weekdayLabels.map((w, i) => (
              <div
                key={i}
                className="h-7 flex items-center justify-center text-xs font-semibold"
                style={{ color: "var(--on-surface-variant)" }}
              >
                {w}
              </div>
            ))}
          </div>

          <div className="grid grid-cols-7 gap-1">
            {weeks.flat().map((day) => {
              const disabled = (min && isBefore(day, min)) || (max && isAfter(day, max));
              const isSelected = selected && isSameDay(day, selected);
              const inMonth = isSameMonth(day, viewDate);
              return (
                <button
                  type="button"
                  key={day.toISOString()}
                  disabled={disabled}
                  onClick={() => {
                    onChange(format(day, "yyyy-MM-dd"));
                    setOpen(false);
                  }}
                  className="h-8 w-8 flex items-center justify-center rounded-full text-sm tabular transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
                  style={{
                    background: isSelected ? "var(--primary)" : "transparent",
                    color: isSelected ? "#1E1F18" : inMonth ? "var(--on-surface)" : "var(--on-surface-variant)",
                    fontWeight: isSelected ? 600 : 400,
                  }}
                >
                  {day.getDate()}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
