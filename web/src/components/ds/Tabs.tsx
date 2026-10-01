"use client";

import { useEffect, useRef, type KeyboardEvent } from "react";

export interface TabItem<T extends string> {
  value: T;
  label: string;
  /** A small `--text-3` number after the label — "Foods 18". */
  count?: number;
}

export interface TabsProps<T extends string> {
  items: TabItem<T>[];
  value: T;
  onChange: (value: T) => void;
  /** `underline` — 3px primary, for page sections. `pill` — the segmented
   *  track's lifted pill, for a denser tab bar. */
  variant?: "underline" | "pill";
  "aria-label"?: string;
}

/**
 * Page-section tabs (D-W0.7) — horizontal scroll under 768px, with the
 * selected tab always scrolled into view (the fix for `client-079`'s
 * overflowing tab bar cutting the active tab off-screen).
 */
export function Tabs<T extends string>({ items, value, onChange, variant = "underline", ...aria }: TabsProps<T>) {
  const refs = useRef(new Map<string, HTMLButtonElement>());

  useEffect(() => {
    refs.current.get(value)?.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" });
  }, [value]);

  function handleKeyDown(e: KeyboardEvent<HTMLButtonElement>, index: number) {
    if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
    e.preventDefault();
    const dir = e.key === "ArrowRight" ? 1 : -1;
    const next = items[(index + dir + items.length) % items.length];
    onChange(next.value);
    refs.current.get(next.value)?.focus();
  }

  const pill = variant === "pill";

  return (
    <div
      role="tablist"
      aria-label={aria["aria-label"]}
      className="flex gap-1 overflow-x-auto"
      style={{ borderBottom: pill ? undefined : "1px solid var(--hairline)" }}
    >
      {items.map((item, i) => {
        const active = item.value === value;
        return (
          <button
            key={item.value}
            ref={(el) => {
              if (el) refs.current.set(item.value, el);
            }}
            type="button"
            role="tab"
            aria-selected={active}
            tabIndex={active ? 0 : -1}
            onClick={() => onChange(item.value)}
            onKeyDown={(e) => handleKeyDown(e, i)}
            className={
              pill
                ? "shrink-0 whitespace-nowrap px-4 h-9 rounded-[var(--r-pill)] type-body-s"
                : "shrink-0 whitespace-nowrap px-4 h-11 type-body-s"
            }
            style={{
              color: active ? "var(--text)" : "var(--text-2)",
              fontWeight: active ? 700 : 600,
              background: pill ? (active ? "var(--segment-selected-bg)" : "transparent") : undefined,
              boxShadow: pill && active ? "var(--segment-shadow)" : undefined,
              borderBottom: pill ? undefined : `3px solid ${active ? "var(--primary)" : "transparent"}`,
              marginBottom: pill ? undefined : -1,
              transition: `color var(--dur-hover) var(--ease-standard), background var(--dur-hover) var(--ease-standard)`,
            }}
          >
            {item.label}
            {item.count != null && (
              <>
                {" "}
                <span className="tabular ml-0.5" style={{ color: "var(--text-3)", fontWeight: 600 }}>
                  {item.count}
                </span>
              </>
            )}
          </button>
        );
      })}
    </div>
  );
}
