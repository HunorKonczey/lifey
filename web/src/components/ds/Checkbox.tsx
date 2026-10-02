import type { KeyboardEvent } from "react";
import { Icon } from "./Icon";

export interface CheckboxProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  "aria-label"?: string;
}

/** 22px, r7 snapped to the 8px radius step (D-W0.5's scale wins over an
 *  off-scale canvas sample, the same rule as the Google button/nav tooltip). */
export function Checkbox({ checked, onChange, label, ...aria }: CheckboxProps) {
  function handleKeyDown(e: KeyboardEvent<HTMLSpanElement>) {
    if (e.key === " " || e.key === "Enter") {
      e.preventDefault();
      onChange(!checked);
    }
  }

  return (
    <label className="inline-flex items-center gap-2 cursor-pointer select-none">
      <span
        role="checkbox"
        aria-checked={checked}
        aria-label={aria["aria-label"] ?? label}
        tabIndex={0}
        onClick={() => onChange(!checked)}
        onKeyDown={handleKeyDown}
        className="inline-flex items-center justify-center shrink-0"
        style={{
          width: 22,
          height: 22,
          borderRadius: "var(--r-tag)",
          background: checked ? "var(--primary)" : "var(--control)",
          // Composed with --shadow-focus (globals.css) — an inline
          // box-shadow always beats the :focus-visible stylesheet rule.
          boxShadow: checked ? undefined : "inset 0 0 0 1px var(--outline), var(--shadow-focus)",
          transition: `background var(--dur-hover) var(--ease-standard)`,
        }}
      >
        {checked && <Icon name="check" size={16} weight={700} color="var(--on-primary)" />}
      </span>
      {label && <span className="type-body-s">{label}</span>}
    </label>
  );
}
