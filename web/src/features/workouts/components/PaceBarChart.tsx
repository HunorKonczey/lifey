"use client";

import { useState } from "react";
import { PaceBarGeometry } from "../paceBarGeometry";
import { buildPaceBars } from "../paceBars";
import type { CardioSplitResponse } from "../types";

const WIDTH = 400;
const HEIGHT = 150;

interface PaceBarChartProps {
  splits: CardioSplitResponse[];
  accent: string;
}

/**
 * Per-split pace as discrete bars, **taller = faster** (docs/cardio/60 §8
 * C6w.3, M33) — the web port of the mobile `PaceBarChart`. Optional: the
 * `CardioSplitsTable` above it already shows the same numbers, this is only
 * the mobile's visual parallel. Takes the exact same `session.splits` prop
 * as the table (`buildPaceBars` sorts/derives `partial` the same way
 * `CardioSplitsTable` orders its rows), so the two views of one split list
 * never disagree.
 *
 * Selection here is **local to the chart** — clicking a bar only highlights
 * that bar, it doesn't cross-highlight a `CardioSplitsTable` row. Mobile
 * links the two because they sit in the same screen state; the web table
 * doesn't have a selection concept yet, and wiring one up is more than this
 * optional step calls for.
 */
export function PaceBarChart({ splits, accent }: PaceBarChartProps) {
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const bars = buildPaceBars(splits);
  if (bars.length < 2) return null;

  const geometry = new PaceBarGeometry(bars, WIDTH, HEIGHT);
  const averageY = geometry.averageLineY;
  const fastestIndex = geometry.fastestIndex;
  const radius = Math.min(7, geometry.barWidth / 2);

  return (
    <svg
      viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
      className="w-full h-auto"
      role="img"
      aria-hidden="true"
    >
      {averageY != null && (
        <line
          x1={0}
          y1={averageY}
          x2={WIDTH}
          y2={averageY}
          stroke="var(--outline)"
          strokeWidth={1}
          strokeDasharray="3 5"
        />
      )}

      {bars.map((bar, i) => {
        const rect = geometry.barRect(i);
        const selected = i === selectedIndex;
        return (
          <rect
            key={i}
            x={rect.x}
            y={rect.y}
            width={rect.width}
            height={rect.height}
            rx={radius}
            fill={bar.partial ? "var(--outline)" : accent}
            fillOpacity={bar.partial || selected ? 1 : 0.62}
            className="cursor-pointer"
            onClick={() => setSelectedIndex(selectedIndex === i ? null : i)}
          />
        );
      })}

      {fastestIndex != null && (
        <text
          x={geometry.barRect(fastestIndex).x + geometry.barRect(fastestIndex).width / 2}
          y={Math.max(9, geometry.barRect(fastestIndex).y - 4)}
          textAnchor="middle"
          fontSize={9}
          fontWeight={800}
          fill={accent}
        >
          {bars[fastestIndex].label}
        </text>
      )}
    </svg>
  );
}
