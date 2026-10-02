"use client";

import { useId, useState } from "react";
import { useLocale } from "next-intl";
import { createFormat } from "@/lib/format/lifeyFormat";
import { Field, fieldDescribedBy } from "./Field";

export interface TimeFieldProps {
  label?: string;
  hint?: string;
  error?: string;
  size?: "auth" | "dense";
  /** 24-hour "HH:mm", e.g. "17:30" — never seconds. */
  value: string;
  onChange: (value: string) => void;
  /** Chips below the field, e.g. ["17:30", "18:30"] (D-W0.9). */
  quickTimes?: string[];
  disabled?: boolean;
  required?: boolean;
  id?: string;
  className?: string;
}

function toDate(hhmm: string): Date {
  const [h, m] = hhmm.split(":").map(Number);
  return new Date(2000, 0, 1, h || 0, m || 0);
}

function isValidTime(text: string): boolean {
  return /^([01]?\d|2[0-3]):[0-5]\d$/.test(text.trim());
}

/**
 * 24-hour while editing (typing "17:30" isn't ambiguous the way typing an
 * AM/PM string would be), the locale's own display at rest — "18:00" HU,
 * "6:00 PM" EN (D-W0.9) — via `lifeyFormat.time`, never a native
 * `<input type="time">`, whose per-browser chrome the design system doesn't
 * control.
 */
export function TimeField({
  label,
  hint,
  error,
  size,
  value,
  onChange,
  quickTimes,
  disabled,
  required,
  id,
  className,
}: TimeFieldProps) {
  const locale = useLocale();
  const format = createFormat(locale);
  const autoId = useId();
  const inputId = id ?? autoId;
  const [focused, setFocused] = useState(false);
  const [text, setText] = useState(value);
  // Resync from `value` during render, not an effect (same reasoning as
  // NumberField) — but only while not focused: a fresh external `value`
  // shouldn't overwrite what the user is mid-way through typing.
  const [prevValue, setPrevValue] = useState(value);
  if (!focused && value !== prevValue) {
    setPrevValue(value);
    setText(value);
  }

  function commit(raw: string) {
    const trimmed = raw.trim();
    if (trimmed === "" && !required) {
      // An optional time can be cleared: empty stays empty (the placeholder shows), it never turns into 00:00.
      onChange("");
      setText("");
      setPrevValue("");
    } else if (isValidTime(trimmed)) {
      const [h, m] = trimmed.split(":");
      const normalized = `${h.padStart(2, "0")}:${m}`;
      onChange(normalized);
      setText(normalized);
      setPrevValue(normalized);
    } else {
      setText(value);
    }
    setFocused(false);
  }

  const displayValue = focused ? text : value === "" ? "" : format.time(toDate(value));

  return (
    <div className={className}>
      <Field label={label} hint={hint} error={error} required={required} disabled={disabled} htmlFor={inputId} size={size}>
        <input
          id={inputId}
          inputMode="numeric"
          placeholder="HH:mm"
          value={displayValue}
          disabled={disabled}
          required={required}
          aria-invalid={!!error}
          aria-describedby={fieldDescribedBy(inputId, error, hint)}
          onFocus={() => {
            setFocused(true);
            setText(value);
          }}
          onChange={(e) => setText(e.target.value)}
          onBlur={(e) => commit(e.target.value)}
          className="tabular"
        />
      </Field>
      {quickTimes && quickTimes.length > 0 && (
        <div className="flex gap-1.5 mt-1.5">
          {quickTimes.map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => onChange(t)}
              className="px-2.5 h-7 type-label rounded-[var(--r-pill)]"
              style={{ background: "var(--control)", color: "var(--text-2)" }}
            >
              {format.time(toDate(t))}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
