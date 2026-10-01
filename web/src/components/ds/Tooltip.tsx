import type { ReactElement } from "react";

export interface TooltipProps {
  label: string;
  /** A short shortcut chip shown beside the label, e.g. "N" or "⌘K". */
  shortcut?: string;
  children: ReactElement;
}

/**
 * An inverse-surface tooltip on hover **and** keyboard focus (D-W0.17) —
 * `--text`-on-`--bg` is already the theme's own inversion, so no separate
 * "inverse surface" token is needed. CSS-only (`:hover`/`:focus-within`);
 * anchored positioning (flip near an edge) is `useAnchoredPosition` in
 * W0.11 — this always opens above its trigger.
 */
export function Tooltip({ label, shortcut, children }: TooltipProps) {
  return (
    <span className="relative inline-flex lifey-tooltip-anchor">
      {children}
      <span
        role="tooltip"
        // Not on a phone: there is no hover, and a hidden tooltip near the right edge still widened the scrollable area (the page could slide sideways).
        className="lifey-tooltip pointer-events-none absolute left-1/2 -translate-x-1/2 bottom-full mb-2 z-10 whitespace-nowrap opacity-0 max-md:hidden"
        style={{
          background: "var(--text)",
          color: "var(--bg)",
          borderRadius: "var(--r-tag)",
          padding: "4px 8px",
          fontSize: 12,
          fontWeight: 600,
          lineHeight: "16px",
        }}
      >
        {label}
        {shortcut && (
          <kbd
            className="ml-1.5"
            style={{ opacity: 0.7, fontFamily: "inherit", fontWeight: 700 }}
          >
            {shortcut}
          </kbd>
        )}
      </span>
    </span>
  );
}
