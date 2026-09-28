"use client";

import type { ReactNode } from "react";
import { AnimatedFill } from "../AnimatedFill";

export interface RingSweeps {
  lap: number;
  overflow: number;
}

/**
 * Splits a progress ratio into the two arcs a ring draws (D-W0.16, ported
 * byte-for-byte from mobile's R0.9 `ringSweeps`): the first lap (0–1) and,
 * past the goal, the overflow lap (0–1) drawn on top of it. NaN/negative
 * counts as 0; the overflow lap is capped at one full turn, so no single arc
 * ever sweeps past 360°.
 */
export function ringSweeps(progress: number): RingSweeps {
  const p = Number.isNaN(progress) ? 0 : progress;
  if (p <= 0) return { lap: 0, overflow: 0 };
  if (p <= 1) return { lap: p, overflow: 0 };
  return { lap: 1, overflow: Math.min(p - 1, 1) };
}

export interface ProgressRingProps {
  /** value / goal; 1 = goal reached, > 1 = over. */
  progress: number;
  color: string;
  size?: number;
  strokeWidth?: number;
  /** Recolours the overflow lap — defaults to `color` (D-W0.16: no extra
   *  colour, so "colour means data" holds; pass this only when a screen
   *  wants the over-goal state louder). */
  overColor?: string;
  /** Entrance stagger — D-W0.13's 60ms-between-macros pattern. */
  delayMs?: number;
  /** Centred content, e.g. a `MetricValue`. */
  children?: ReactNode;
  /** e.g. "Calories, 26% of goal" — read instead of the ring; omit for a
   *  purely decorative ring next to its own separately-labelled value. */
  "aria-label"?: string;
}

const START_ANGLE = -Math.PI / 2;

/**
 * A circular progress ring (D-W0.16): dashboard hero 144, macro rings 88,
 * week-strip rings 30. 12 o'clock start, round caps, the track in
 * `--control`, fill in the metric colour; stroke defaults to 15/160 of the
 * size. Fills in from 0 on first appearance (`AnimatedFill`, 900ms), later
 * changes animate only the difference.
 *
 * Past the goal the ring completes and a second lap runs over it in the
 * same colour, with a soft shadow under its leading end so the overlap
 * reads (ported from mobile's `progress_ring.dart`).
 */
export function ProgressRing({
  progress,
  color,
  size = 144,
  strokeWidth,
  overColor,
  delayMs = 0,
  children,
  ...aria
}: ProgressRingProps) {
  const stroke = strokeWidth ?? (size * 15) / 160;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const center = size / 2;
  const label = aria["aria-label"];

  return (
    <div
      className="relative inline-flex items-center justify-center shrink-0"
      style={{ width: size, height: size }}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      <AnimatedFill value={Number.isNaN(progress) ? 0 : progress} delayMs={delayMs}>
        {(animated) => {
          const { lap, overflow } = ringSweeps(animated);
          const lapLength = lap * circumference;
          const overflowLength = overflow * circumference;
          let tipX = center;
          let tipY = center - radius;
          if (overflow > 0) {
            const end = START_ANGLE + overflow * 2 * Math.PI;
            tipX = center + Math.cos(end) * radius;
            tipY = center + Math.sin(end) * radius;
          }
          return (
            <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="absolute inset-0">
              <circle cx={center} cy={center} r={radius} fill="none" stroke="var(--control)" strokeWidth={stroke} />
              {lap > 0 && (
                <circle
                  cx={center}
                  cy={center}
                  r={radius}
                  fill="none"
                  stroke={color}
                  strokeWidth={stroke}
                  strokeLinecap="round"
                  strokeDasharray={`${lapLength} ${circumference}`}
                  transform={`rotate(-90 ${center} ${center})`}
                />
              )}
              {overflow > 0 && (
                <>
                  <circle cx={tipX} cy={tipY} r={stroke / 2} fill="black" opacity={0.45} style={{ filter: `blur(${stroke / 3}px)` }} />
                  <circle
                    cx={center}
                    cy={center}
                    r={radius}
                    fill="none"
                    stroke={overColor ?? color}
                    strokeWidth={stroke}
                    strokeLinecap="round"
                    strokeDasharray={`${overflowLength} ${circumference}`}
                    transform={`rotate(-90 ${center} ${center})`}
                  />
                </>
              )}
            </svg>
          );
        }}
      </AnimatedFill>
      {children}
    </div>
  );
}
