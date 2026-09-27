"use client";

import { useRef, type KeyboardEvent } from "react";
import { Icon } from "./Icon";

export interface SegmentedControlOption<T extends string> {
  value: T;
  label: string;
  icon?: string;
}

export interface SegmentedControlProps<T extends string> {
  options: SegmentedControlOption<T>[];
  value: T;
  onChange: (value: T) => void;
  size?: "sm" | "md";
  "aria-label"?: string;
}

/**
 * A pill track with a lifted selected segment (D-W0.7/DS-03) — `radiogroup`
 * semantics, arrow keys move the selection (roving `tabIndex`), replaces
 * `components/ui/SegmentedControl.tsx` at each call site's own iteration.
 */
export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  size = "md",
  ...aria
}: SegmentedControlProps<T>) {
  const refs = useRef(new Map<string, HTMLButtonElement>());

  function handleKeyDown(e: KeyboardEvent<HTMLButtonElement>, index: number) {
    if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
    e.preventDefault();
    const dir = e.key === "ArrowRight" ? 1 : -1;
    const next = options[(index + dir + options.length) % options.length];
    onChange(next.value);
    refs.current.get(next.value)?.focus();
  }

  const pad = size === "sm" ? "px-3 h-8 text-xs" : "px-4 h-9 type-body-s";

  return (
    <div
      role="radiogroup"
      aria-label={aria["aria-label"]}
      className="inline-flex max-w-full overflow-x-auto gap-0.5 p-1 rounded-[var(--r-pill)]"
      style={{ background: "var(--control)" }}
    >
      {options.map((opt, i) => {
        const active = opt.value === value;
        return (
          <button
            key={opt.value}
            ref={(el) => {
              if (el) refs.current.set(opt.value, el);
            }}
            type="button"
            role="radio"
            aria-checked={active}
            tabIndex={active ? 0 : -1}
            onClick={() => onChange(opt.value)}
            onKeyDown={(e) => handleKeyDown(e, i)}
            className={`flex shrink-0 whitespace-nowrap items-center gap-1.5 rounded-[var(--r-pill)] ${pad}`}
            style={{
              background: active ? "var(--segment-selected-bg)" : "transparent",
              // Composed with --shadow-focus (globals.css) — an inline
              // box-shadow always beats the :focus-visible stylesheet rule.
              boxShadow: active ? "var(--segment-shadow), var(--shadow-focus)" : undefined,
              color: active ? "var(--text)" : "var(--text-2)",
              fontWeight: active ? 700 : 600,
              transition: `background var(--dur-hover) var(--ease-standard)`,
            }}
          >
            {opt.icon && <Icon name={opt.icon} size={16} fill={active ? 1 : 0} />}
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
