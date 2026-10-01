"use client";

import { useId, useRef, useState } from "react";
import { useLocale } from "next-intl";
import { isHuLocale } from "@/lib/format/lifeyFormat";
import { Field } from "../field/Field";

export interface DateFieldsProps {
  label?: string;
  hint?: string;
  error?: string;
  value: Date | null;
  onChange: (date: Date | null) => void;
  disabled?: boolean;
  required?: boolean;
  id?: string;
  className?: string;
}

type Segment = "year" | "month" | "day";

const HU_ORDER: Segment[] = ["year", "month", "day"];
const EN_ORDER: Segment[] = ["month", "day", "year"];
const PLACEHOLDER: Record<Segment, string> = { year: "ÉÉÉÉ", month: "HH", day: "NN" };
const PLACEHOLDER_EN: Record<Segment, string> = { year: "YYYY", month: "MM", day: "DD" };

function partsFrom(value: Date | null) {
  return {
    year: value ? String(value.getFullYear()) : "",
    month: value ? String(value.getMonth() + 1).padStart(2, "0") : "",
    day: value ? String(value.getDate()).padStart(2, "0") : "",
  };
}

/**
 * Typed date segments in locale order (D-W0.10) — HU year·month·day, EN
 * month·day·year (`onboarding-004`'s birth-date field) — never a native
 * `<input type="date">`, whose segment order the browser/OS controls, not
 * this design system.
 */
export function DateFields({ label, hint, error, value, onChange, disabled, required, id, className }: DateFieldsProps) {
  const locale = useLocale();
  const hu = isHuLocale(locale);
  const order = hu ? HU_ORDER : EN_ORDER;
  const placeholders = hu ? PLACEHOLDER : PLACEHOLDER_EN;
  const autoId = useId();
  const inputId = id ?? autoId;
  const [parts, setParts] = useState(() => partsFrom(value));
  const refs = useRef<Partial<Record<Segment, HTMLInputElement | null>>>({});

  function commit(next: typeof parts) {
    setParts(next);
    const y = Number(next.year);
    const m = Number(next.month);
    const d = Number(next.day);
    if (next.year.length === 4 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      const date = new Date(y, m - 1, d);
      // Guards Feb 30 etc. rolling into the next month.
      onChange(date.getMonth() === m - 1 ? date : null);
    } else {
      onChange(null);
    }
  }

  function handleSegmentChange(seg: Segment, raw: string) {
    const maxLen = seg === "year" ? 4 : 2;
    const digits = raw.replace(/\D/g, "").slice(0, maxLen);
    const next = { ...parts, [seg]: digits };
    commit(next);
    if (digits.length === maxLen) {
      const nextSeg = order[order.indexOf(seg) + 1];
      if (nextSeg) refs.current[nextSeg]?.focus();
    }
  }

  return (
    <Field label={label} hint={hint} error={error} required={required} disabled={disabled} htmlFor={inputId} className={className}>
      {order.map((seg, i) => (
        <span key={seg} className="flex items-center gap-1">
          {i > 0 && (
            <span aria-hidden="true" style={{ color: "var(--text-3)" }}>
              {hu ? "." : "/"}
            </span>
          )}
          <input
            ref={(el) => {
              refs.current[seg] = el;
            }}
            id={seg === order[0] ? inputId : undefined}
            inputMode="numeric"
            placeholder={placeholders[seg]}
            value={parts[seg]}
            disabled={disabled}
            maxLength={seg === "year" ? 4 : 2}
            onChange={(e) => handleSegmentChange(seg, e.target.value)}
            className="tabular text-center"
            style={{ width: seg === "year" ? "3.2em" : "2em" }}
            aria-label={label ? `${label} – ${seg}` : seg}
          />
        </span>
      ))}
    </Field>
  );
}
