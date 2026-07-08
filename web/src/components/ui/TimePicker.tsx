"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";

const HOURS = Array.from({ length: 24 }, (_, i) => i);
const MINUTES = Array.from({ length: 60 }, (_, i) => i);

function pad(n: number) {
  return n.toString().padStart(2, "0");
}

interface TimePickerProps {
  /** "HH:mm", or "" when unset. */
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  hasError?: boolean;
  id?: string;
}

/** Dropdown time picker matching the app's input styling, mirroring
 *  `DatePicker`. Native `<input type="time">` renders its own clock icon
 *  and popup, inconsistent with the rest of the design. */
export function TimePicker({ value, onChange, placeholder, hasError, id }: TimePickerProps) {
  const t = useTranslations("common");
  const [hourStr, minuteStr] = value ? value.split(":") : ["", ""];
  const hour = hourStr !== "" ? Number(hourStr) : undefined;
  const minute = minuteStr !== "" ? Number(minuteStr) : undefined;

  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

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

  const setHour = (h: number) => onChange(`${pad(h)}:${pad(minute ?? 0)}`);
  const setMinute = (m: number) => onChange(`${pad(hour ?? 0)}:${pad(m)}`);

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
        <span style={{ color: value ? "var(--on-surface)" : "var(--on-surface-variant)" }}>
          {value ? `${pad(hour ?? 0)}:${pad(minute ?? 0)}` : (placeholder ?? t("selectTime"))}
        </span>
        <span className="material-symbols-rounded text-lg" style={{ color: "var(--on-surface-variant)" }}>
          schedule
        </span>
      </button>

      {open && (
        <div
          className="absolute z-20 mt-2 p-2 rounded-[var(--r-card)] shadow-lg w-40 flex gap-1"
          style={{ background: "var(--surface-high)", border: "1px solid var(--outline)" }}
        >
          <div className="flex-1 max-h-48 overflow-y-auto flex flex-col gap-0.5">
            {HOURS.map((h) => {
              const selected = h === hour;
              return (
                <button
                  type="button"
                  key={h}
                  onClick={() => setHour(h)}
                  className="h-8 rounded-lg text-sm tabular transition-colors"
                  style={{
                    background: selected ? "var(--primary)" : "transparent",
                    color: selected ? "#1E1F18" : "var(--on-surface)",
                    fontWeight: selected ? 600 : 400,
                  }}
                >
                  {pad(h)}
                </button>
              );
            })}
          </div>
          <div className="flex-1 max-h-48 overflow-y-auto flex flex-col gap-0.5">
            {MINUTES.map((m) => {
              const selected = m === minute;
              return (
                <button
                  type="button"
                  key={m}
                  onClick={() => setMinute(m)}
                  className="h-8 rounded-lg text-sm tabular transition-colors"
                  style={{
                    background: selected ? "var(--primary)" : "transparent",
                    color: selected ? "#1E1F18" : "var(--on-surface)",
                    fontWeight: selected ? 600 : 400,
                  }}
                >
                  {pad(m)}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
