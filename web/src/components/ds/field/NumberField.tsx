"use client";

import { useId, useState, type KeyboardEvent, type Ref } from "react";
import { useLocale, useTranslations } from "next-intl";
import { Icon } from "../Icon";
import { Field, fieldDescribedBy } from "./Field";
import { clampNumber, formatLocaleNumber, parseLocaleNumber, roundToDecimals } from "./numberFormat";

export interface NumberFieldProps {
  label?: string;
  hint?: string;
  error?: string;
  size?: "auth" | "dense";
  value: number;
  onChange: (value: number) => void;
  unit?: string;
  step?: number;
  min?: number;
  max?: number;
  /** Max decimals shown and accepted. Default 1 (D-W0.9's "166,7 g", never "166.68"). */
  maxDecimals?: number;
  disabled?: boolean;
  required?: boolean;
  id?: string;
  className?: string;
  /** Names the input when there is no visible `label` (a quantity beside its food's name). */
  "aria-label"?: string;
  /** The inner `<input>` — for a dialog that focuses the quantity on Tab. */
  inputRef?: Ref<HTMLInputElement>;
  /** Report every parseable keystroke through `onChange` instead of only on blur / Enter, so a
   *  live preview follows what is being typed. The text itself is left as typed until blur. */
  liveUpdate?: boolean;
  /** Select the whole number on focus so typing replaces it. */
  selectOnFocus?: boolean;
  /** Enter was pressed; the typed value has just been committed through `onChange`. */
  onEnter?: () => void;
}

/**
 * A number field with the unit inside it, −/+ steppers, and the locale's own
 * decimal separator on both display and input (D-W0.9) — "166,7 g" typed
 * with a comma in Hungarian, never "166.68". Arrow keys step by `step`,
 * Shift+arrow by 10×.
 */
export function NumberField({
  label,
  hint,
  error,
  size,
  value,
  onChange,
  unit,
  step = 1,
  min,
  max,
  maxDecimals = 1,
  disabled,
  required,
  id,
  className,
  inputRef,
  liveUpdate,
  selectOnFocus,
  onEnter,
  ...aria
}: NumberFieldProps) {
  const locale = useLocale();
  const common = useTranslations("common");
  const autoId = useId();
  const inputId = id ?? autoId;
  const [text, setText] = useState(() => formatLocaleNumber(value, locale, maxDecimals));

  // Resync `text` from `value`/`locale` during render (React's documented
  // pattern for state derived from a prop — see
  // https://react.dev/learn/you-might-not-need-an-effect), not in a
  // useEffect: an effect would still be correct here, but the lint rule
  // (react-hooks/set-state-in-effect) flags any setState called directly in
  // an effect body, and this doesn't need the effect's extra render pass.
  const [prevSync, setPrevSync] = useState({ value, locale, maxDecimals });
  if (prevSync.value !== value || prevSync.locale !== locale || prevSync.maxDecimals !== maxDecimals) {
    setPrevSync({ value, locale, maxDecimals });
    setText(formatLocaleNumber(value, locale, maxDecimals));
  }

  function applyDelta(delta: number) {
    const next = clampNumber(roundToDecimals(value + delta, maxDecimals), min, max);
    onChange(next);
    setText(formatLocaleNumber(next, locale, maxDecimals));
  }

  function commit(raw: string) {
    const parsed = parseLocaleNumber(raw, locale);
    if (parsed === null) {
      setText(formatLocaleNumber(value, locale, maxDecimals));
      return;
    }
    const clamped = clampNumber(roundToDecimals(parsed, maxDecimals), min, max);
    onChange(clamped);
    setText(formatLocaleNumber(clamped, locale, maxDecimals));
  }

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter" && onEnter) {
      e.preventDefault();
      commit(e.currentTarget.value);
      onEnter();
      return;
    }
    if (e.key !== "ArrowUp" && e.key !== "ArrowDown") return;
    e.preventDefault();
    const magnitude = e.shiftKey ? step * 10 : step;
    applyDelta(e.key === "ArrowUp" ? magnitude : -magnitude);
  }

  return (
    <Field label={label} hint={hint} error={error} required={required} disabled={disabled} htmlFor={inputId} size={size} className={className}>
      <button type="button" onClick={() => applyDelta(-step)} disabled={disabled} aria-label={common("decrease")} className="shrink-0">
        <Icon name="remove" size={16} color="var(--text-2)" />
      </button>
      <input
        id={inputId}
        aria-label={aria["aria-label"]}
        inputMode="decimal"
        value={text}
        disabled={disabled}
        required={required}
        aria-invalid={!!error}
        aria-describedby={fieldDescribedBy(inputId, error, hint)}
        ref={inputRef}
        onChange={(e) => {
          setText(e.target.value);
          if (liveUpdate) {
            const parsed = parseLocaleNumber(e.target.value, locale);
            if (parsed !== null) onChange(roundToDecimals(parsed, maxDecimals));
          }
        }}
        onFocus={selectOnFocus ? (e) => e.currentTarget.select() : undefined}
        onBlur={(e) => commit(e.target.value)}
        onKeyDown={handleKeyDown}
        className="tabular text-center"
      />
      {unit && (
        <span className="type-body-s shrink-0" style={{ color: "var(--text-2)" }}>
          {unit}
        </span>
      )}
      <button type="button" onClick={() => applyDelta(step)} disabled={disabled} aria-label={common("increase")} className="shrink-0">
        <Icon name="add" size={16} color="var(--text-2)" />
      </button>
    </Field>
  );
}
