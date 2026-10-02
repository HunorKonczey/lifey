"use client";

import { AnimatedFill } from "../AnimatedFill";

export interface SegmentBarProps {
  /** Total number of segments — 10 for the water tile (D-W0.16). */
  segments?: number;
  /** Overall value / goal, 0–1+; extra progress past 1 fills nothing further
   *  (every segment is already full). */
  progress: number;
  color: string;
  height?: number;
  gap?: number;
}

/**
 * A discrete step bar — the water tile's 10 segments (D-W0.16). At rest each
 * segment is full, a fixed 45%-filled "partial" (the one segment straddling
 * the boundary, shown at a constant fill rather than its exact fractional
 * remainder — a full/near-empty sliver reads worse than a consistent partial
 * mark), or empty (`--control`). While the value is changing the fill runs
 * continuously across the segments (`AnimatedFill`: from 0 on first
 * appearance, afterwards only the difference animates — D-W0.13), and settles
 * into the resting shapes at the end.
 */
export function SegmentBar({ segments = 10, progress, color, height = 16, gap = 4 }: SegmentBarProps) {
  const p = Number.isNaN(progress) ? 0 : Math.max(0, progress);
  const target = Math.min(1, p);
  const filled = Math.min(segments, Math.floor(p * segments));
  const hasPartial = filled < segments && p * segments > filled;
  const radius = height / 3;

  return (
    <AnimatedFill value={target}>
      {(animated) => {
        const settled = Math.abs(animated - target) < 1e-6;
        return (
          <div className="flex" style={{ gap }}>
            {Array.from({ length: segments }, (_, i) => {
              let width: number;
              if (settled) {
                width = i < filled ? 1 : i === filled && hasPartial ? 0.45 : 0;
              } else {
                width = Math.min(1, Math.max(0, animated * segments - i));
              }
              return (
                <div key={i} className="flex-1 overflow-hidden" style={{ height, borderRadius: radius, background: "var(--control)" }}>
                  {width > 0 && <div style={{ height: "100%", width: `${width * 100}%`, background: color, borderRadius: radius }} />}
                </div>
              );
            })}
          </div>
        );
      }}
    </AnimatedFill>
  );
}
