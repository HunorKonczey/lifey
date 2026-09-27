"use client";

import { useRef, type KeyboardEvent } from "react";
import { Icon } from "./Icon";

export interface ChoiceTileOption<T extends string> {
  value: T;
  label: string;
  description?: string;
  icon?: string;
}

interface ChoiceTileGroupBase<T extends string> {
  options: ChoiceTileOption<T>[];
  "aria-label"?: string;
  className?: string;
}

export interface ChoiceTileRadioProps<T extends string> extends ChoiceTileGroupBase<T> {
  mode?: "radio";
  value: T;
  onChange: (value: T) => void;
}

export interface ChoiceTileCheckboxProps<T extends string> extends ChoiceTileGroupBase<T> {
  mode: "checkbox";
  value: T[];
  onChange: (value: T[]) => void;
}

export type ChoiceTileGroupProps<T extends string> = ChoiceTileRadioProps<T> | ChoiceTileCheckboxProps<T>;

/**
 * A grid of selectable tiles (D-W0.7, `onboarding-006`) — single-select
 * (`radio`, the default) or multi-select (`checkbox`); either way, arrow
 * keys move focus around the grid and Space toggles, since visually this is
 * a grid, not a list Tab alone would serve well.
 */
export function ChoiceTileGroup<T extends string>(props: ChoiceTileGroupProps<T>) {
  const { options, className } = props;
  const refs = useRef(new Map<string, HTMLButtonElement>());

  const isChecked = (v: T) => (props.mode === "checkbox" ? props.value.includes(v) : props.value === v);

  function toggle(v: T) {
    if (props.mode === "checkbox") {
      const next = props.value.includes(v) ? props.value.filter((x) => x !== v) : [...props.value, v];
      props.onChange(next);
    } else {
      props.onChange(v);
    }
  }

  function handleKeyDown(e: KeyboardEvent<HTMLButtonElement>, index: number) {
    if (e.key === " " || e.key === "Enter") {
      e.preventDefault();
      toggle(options[index].value);
      return;
    }
    if (!["ArrowRight", "ArrowLeft", "ArrowDown", "ArrowUp"].includes(e.key)) return;
    e.preventDefault();
    const dir = e.key === "ArrowRight" || e.key === "ArrowDown" ? 1 : -1;
    const next = options[(index + dir + options.length) % options.length];
    refs.current.get(next.value)?.focus();
  }

  return (
    <div
      role={props.mode === "checkbox" ? "group" : "radiogroup"}
      aria-label={props["aria-label"]}
      className={["grid grid-cols-2 gap-3", className].filter(Boolean).join(" ")}
    >
      {options.map((opt, i) => {
        const active = isChecked(opt.value);
        return (
          <button
            key={opt.value}
            ref={(el) => {
              if (el) refs.current.set(opt.value, el);
            }}
            type="button"
            role={props.mode === "checkbox" ? "checkbox" : "radio"}
            aria-checked={active}
            tabIndex={i === 0 || active ? 0 : -1}
            onClick={() => toggle(opt.value)}
            onKeyDown={(e) => handleKeyDown(e, i)}
            className="relative flex flex-col items-start gap-1 p-4 text-left rounded-[var(--r-card)]"
            style={{
              background: active ? "var(--primary-tint)" : "var(--nested)",
              // Composed with --shadow-focus (globals.css) — an inline
              // box-shadow always beats the :focus-visible stylesheet rule.
              boxShadow: active ? "inset 0 0 0 2px var(--primary), var(--shadow-focus)" : undefined,
              transition: `background var(--dur-hover) var(--ease-standard), box-shadow var(--dur-hover) var(--ease-standard)`,
            }}
          >
            {opt.icon && <Icon name={opt.icon} size={24} fill={active ? 1 : 0} color={active ? "var(--primary)" : "var(--text-2)"} />}
            <span className="type-title-s">{opt.label}</span>
            {opt.description && (
              <span className="type-body-s" style={{ color: "var(--text-2)" }}>
                {opt.description}
              </span>
            )}
            {active && (
              <span className="absolute top-3 right-3">
                <Icon name="check_circle" size={20} fill={1} color="var(--primary)" />
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}
