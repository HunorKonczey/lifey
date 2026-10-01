"use client";

import { Fragment } from "react";
import { AnimatedFill } from "../AnimatedFill";

export interface RatioSegment {
  value: number;
  color: string;
}

/**
 * Width fractions of each segment (D-W0.16, ported byte-for-byte from
 * mobile's `RatioBar.fractions`) — 0–1, summing to at most 1. NaN/negative
 * values count as 0. With `total` (e.g. the day's calorie goal), past-goal
 * segments scale down together to fill the bar instead of overflowing it;
 * without it, segments split the whole bar by their own share (100%).
 */
export function ratioBarFractions(values: number[], total?: number | null): number[] {
  const clean = values.map((v) => (Number.isNaN(v) || v < 0 ? 0 : v));
  const sum = clean.reduce((a, b) => a + b, 0);
  if (sum === 0) return clean.map(() => 0);
  const denominator = total == null || total <= 0 || sum > total ? sum : total;
  return clean.map((v) => v / denominator);
}

export interface RatioBarProps {
  segments: RatioSegment[];
  total?: number | null;
  height?: number;
  gap?: number;
}

/**
 * A segmented bar of parts in their metric colours (D-W0.16, ported from
 * mobile's R0.9 `metric_bar.dart`'s `RatioBar`) — the nutrition day budget's
 * P/C/F bar and the macros tab's daily split. 10px, radius 5, `--control`
 * track, gaps between visible segments only (a zero-fraction segment is
 * skipped, not shown as a zero-width sliver).
 */
export function RatioBar({ segments, total, height = 10, gap = 3 }: RatioBarProps) {
  const fractions = ratioBarFractions(
    segments.map((s) => s.value),
    total,
  );
  const radius = height / 2;
  const visible = fractions.map((f, i) => ({ f, color: segments[i].color, i })).filter((s) => s.f > 0);
  const totalGap = gap * Math.max(0, visible.length - 1);

  return (
    <div className="overflow-hidden flex" style={{ height, borderRadius: radius, background: "var(--control)" }}>
      {visible.map((s, n) => (
        <Fragment key={s.i}>
          {n > 0 && <div style={{ width: gap, flexShrink: 0 }} />}
          <AnimatedFill value={s.f}>
            {(animated) => (
              <div
                style={{
                  width: `calc((100% - ${totalGap}px) * ${animated})`,
                  height: "100%",
                  background: s.color,
                  flexShrink: 0,
                }}
              />
            )}
          </AnimatedFill>
        </Fragment>
      ))}
    </div>
  );
}
