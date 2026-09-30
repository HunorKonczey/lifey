"use client";

import type { ReactNode } from "react";
import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds/Icon";

interface EmptyStateProps {
  icon?: string;
  title?: string;
  body?: string;
  action?: ReactNode;
  /** A secondary, lower-emphasis action beside the primary one (D-W0.17). */
  secondaryAction?: ReactNode;
  /** Tints the icon holder — default `--primary` (DS-05); pass a metric
   *  colour (e.g. `--m-water`) for a metric-specific empty state. */
  color?: string;
  /** Inside a tile rather than a page: tighter padding, a 44px icon holder. */
  compact?: boolean;
}

/**
 * An empty state (D-W0.17/DS-05): a tinted icon holder, a title that says
 * what to do, and body copy with the payoff for doing it.
 */
export function EmptyState({ icon = "inbox", title, body, action, secondaryAction, color = "var(--primary)", compact = false }: EmptyStateProps) {
  const t = useTranslations("status");
  const resolvedTitle = title ?? t("emptyTitle");
  const resolvedBody = body ?? t("emptyBody");
  return (
    <div className={["flex flex-col items-center justify-center text-center", compact ? "gap-3 py-2" : "gap-4 py-16 px-4"].join(" ")}>
      <div
        className={[compact ? "w-11 h-11" : "w-16 h-16", "rounded-full flex items-center justify-center shrink-0"].join(" ")}
        style={{ background: `color-mix(in srgb, ${color} var(--chip-tint), transparent)` }}
      >
        <Icon name={icon} size={compact ? 22 : 28} fill={1} color={color} />
      </div>
      <div>
        <p className={compact ? "type-body mb-0.5" : "type-title-s mb-1"} style={compact ? { fontWeight: 700 } : undefined}>{resolvedTitle}</p>
        <p className="type-body-s max-w-xs" style={{ color: "var(--text-3)" }}>
          {resolvedBody}
        </p>
      </div>
      {(action || secondaryAction) && (
        <div className="flex items-center gap-3">
          {action}
          {secondaryAction}
        </div>
      )}
    </div>
  );
}
