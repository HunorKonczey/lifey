"use client";

import { useState, type KeyboardEvent, type Ref } from "react";
import { useLocale, useTranslations } from "next-intl";
import { IconButton } from "@/components/ds";
import { formatLocaleNumber, parseLocaleNumber } from "@/components/ds/field/numberFormat";
import { clampWeight, stepWeight } from "../logWeight";

/**
 * The log drawer's number (W4.4, client-020): − / **69,6 kg** / + with the value at 72 px. Type it, click − / +, or
 * use the keyboard: ↑/↓ step 0,1 kg, Shift+↑/↓ a whole kilogram, Enter commits and saves. The decimal separator is the
 * UI language's own ("69,6" in Hungarian); a typed comma or dot is understood either way on blur.
 */
export function WeightStepper({
  value,
  onChange,
  onEnter,
  inputRef,
}: {
  value: number;
  onChange: (kg: number) => void;
  /** Enter pressed; receives the value just committed from the text (state has not caught up yet). */
  onEnter?: (kg: number) => void;
  inputRef?: Ref<HTMLInputElement>;
}) {
  const t = useTranslations("weight");
  const common = useTranslations("common");
  const locale = useLocale();
  const [focused, setFocused] = useState(false);
  const [text, setText] = useState(() => formatLocaleNumber(value, locale, 1));
  const [synced, setSynced] = useState(value);
  // Resync the text when the value changes from outside (− / +, a keyboard step) — during render, not in an effect.
  if (synced !== value) {
    setSynced(value);
    setText(formatLocaleNumber(value, locale, 1));
  }

  function commit(raw: string) {
    const parsed = parseLocaleNumber(raw);
    const next = parsed == null ? value : clampWeight(parsed);
    onChange(next);
    setText(formatLocaleNumber(next, locale, 1));
    return next;
  }

  function step(direction: 1 | -1, shift: boolean) {
    const next = stepWeight(value, direction, shift);
    onChange(next);
    setText(formatLocaleNumber(next, locale, 1));
  }

  function onKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      e.preventDefault();
      step(e.key === "ArrowUp" ? 1 : -1, e.shiftKey);
    } else if (e.key === "Enter") {
      e.preventDefault();
      onEnter?.(commit(e.currentTarget.value));
    }
  }

  return (
    <div className="flex items-center justify-center gap-3" data-testid="weight-stepper">
      <IconButton icon="remove" label={common("decrease")} size={40} onClick={() => step(-1, false)} />
      {/* The focus ring sits on the label, not the input: the global :focus-visible outline is an unlayered rule that
          beat the `outline-none` utility and drew a hard black box around the 72 px number (W4 review). */}
      <label
        className="flex min-w-0 items-baseline justify-center gap-2 px-3"
        style={{ borderRadius: "var(--r-control)", boxShadow: focused ? "0 0 0 2px var(--primary)" : "0 0 0 2px transparent", transition: "box-shadow var(--dur-hover) var(--ease-standard)" }}
      >
        <input
          ref={inputRef}
          aria-label={t("weightKg")}
          inputMode="decimal"
          value={text}
          onChange={(e) => setText(e.target.value)}
          onBlur={(e) => {
            setFocused(false);
            commit(e.target.value);
          }}
          onFocus={(e) => {
            setFocused(true);
            e.currentTarget.select();
          }}
          onKeyDown={onKeyDown}
          data-autofocus
          className="tabular min-w-0 bg-transparent text-center outline-none"
          style={{ outline: "none", boxShadow: "none", width: "4.2ch", fontSize: 72, lineHeight: "76px", fontWeight: 800, letterSpacing: "-0.03em", color: "var(--text)" }}
        />
        <span className="type-title" style={{ color: "var(--text-2)" }}>
          kg
        </span>
      </label>
      <IconButton icon="add" label={common("increase")} size={40} onClick={() => step(1, false)} />
    </div>
  );
}
