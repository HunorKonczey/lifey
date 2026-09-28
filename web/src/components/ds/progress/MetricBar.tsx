"use client";

import { AnimatedFill } from "../AnimatedFill";

export interface MetricBarProps {
  /** value / goal, clamped to the bar — an over-goal state is the caller's
   *  own text ("212 kcal over"), not a longer bar. */
  progress: number;
  color: string;
  height?: number;
  delayMs?: number;
}

/**
 * A horizontal progress bar in a metric colour (D-W0.16, ported from
 * mobile's R0.9 `metric_bar.dart`) — the dashboard hero's macro rows and
 * metric tiles. 7px, fully rounded, `--control` track. Fills in from 0 on
 * first appearance, later changes animate only the difference.
 */
export function MetricBar({ progress, color, height = 7, delayMs = 0 }: MetricBarProps) {
  const target = Number.isNaN(progress) ? 0 : Math.min(1, Math.max(0, progress));
  const radius = height / 2;

  return (
    <div className="overflow-hidden" style={{ height, borderRadius: radius, background: "var(--control)" }}>
      <AnimatedFill value={target} delayMs={delayMs}>
        {(animated) => (
          <div
            style={{
              height: "100%",
              width: `${Math.min(1, Math.max(0, animated)) * 100}%`,
              background: color,
              borderRadius: radius,
            }}
          />
        )}
      </AnimatedFill>
    </div>
  );
}
