"use client";

import type { ReactNode } from "react";
import { Card } from "../Card";
import { Icon } from "../Icon";
import type { MenuItemDef } from "../Menu";
import { MetricValue } from "../MetricValue";
import { RowMenuButton } from "../RowMenuButton";
import { MetricBar } from "./MetricBar";
import { SegmentBar } from "./SegmentBar";

export interface MetricTileProps {
  icon: string;
  label: string;
  /** A small trailing header note — "last at 14:10" (D-W0.16). */
  meta?: string;
  value: string | number;
  unit?: string;
  /** Unit size as a fraction of the 26px value — 0.5 by default; a "/ 2,5 L" goal reads better at 0.6. */
  unitRatio?: number;
  color: string;
  /** value / goal for a continuous `MetricBar` — omit when using `segments`. */
  progress?: number;
  /** A discrete `SegmentBar` instead (e.g. water's 10 glasses) — omit when using `progress`. */
  segments?: { count?: number; progress: number; height?: number };
  /** Usually a `DeltaChip`, shown beside the value. */
  delta?: ReactNode;
  /** A secondary line under the value — "Latest entry · today"; a node when it carries an icon. */
  subline?: ReactNode;
  /** Below the bar — the water tile's quick-add row. */
  footer?: ReactNode;
  /** Sits right of the value block (e.g. a sparkline). */
  trailing?: ReactNode;
  /** Quick-action buttons in the header (e.g. a quick-add `IconButton`). */
  actions?: ReactNode;
  rowMenu?: MenuItemDef[];
  rowMenuLabel?: string;
  onClick?: () => void;
  /** Read instead of the parts, e.g. "Water, 0.99 of 2.6 litres". */
  "aria-label"?: string;
  className?: string;
}

/**
 * A metric tile — Water, Steps, Weight on the dashboard (D-W0.16, ported
 * from mobile's R0.9 `metric_tile.dart`, with the web-only `meta`/`rowMenu`
 * additions DS-03 calls for). Card (padding 16, `--r-card`): a header of an
 * 18px filled icon in the metric colour, a 13/600 label, and optional meta
 * text; the value at 26/800 with its unit at 13/600 beside it
 * (`MetricValue`'s tile-specific `unitRatio`); then optionally a delta chip,
 * a progress bar or segment bar, and a subline.
 */
export function MetricTile({
  icon,
  label,
  meta,
  value,
  unit,
  unitRatio = 0.5,
  color,
  progress,
  segments,
  delta,
  subline,
  trailing,
  footer,
  actions,
  rowMenu,
  rowMenuLabel,
  onClick,
  className,
  ...aria
}: MetricTileProps) {
  const semanticsLabel = aria["aria-label"];

  return (
    <Card
      interactive={!!onClick}
      onClick={onClick}
      aria-label={semanticsLabel}
      className={["@container flex flex-col gap-3", className].filter(Boolean).join(" ")}
    >
      <div className="flex items-center gap-1.5" style={{ height: 32 }}>
        <Icon name={icon} size={18} fill={1} color={color} />
        <span className="type-body-s truncate" style={{ color: "var(--text-2)" }}>
          {label}
        </span>
        <div className="flex-1 min-w-0" />
        {meta && (
          <span className="type-body-s shrink-0 hidden @[200px]:inline" style={{ color: "var(--text-3)" }}>
            {meta}
          </span>
        )}
        {actions}
        {rowMenu && <RowMenuButton items={rowMenu} label={rowMenuLabel} />}
      </div>

      <div className="flex items-end gap-3">
        <div className="flex-1 min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <MetricValue value={value} unit={unit} size={26} unitRatio={unitRatio} />
            {delta}
          </div>
          {subline && (
            <p className="type-body-s mt-1.5" style={{ color: "var(--text-3)" }}>
              {subline}
            </p>
          )}
        </div>
        {trailing}
      </div>

      {progress != null && <MetricBar progress={progress} color={color} />}
      {segments && <SegmentBar segments={segments.count} progress={segments.progress} color={color} height={segments.height} />}
      {footer}
    </Card>
  );
}
