"use client";

import { useEffect, useRef, useState } from "react";
import { useReducedMotion } from "@/lib/hooks/useReducedMotion";

export interface AnimatedNumberProps {
  value: number;
  /** Renders the (possibly fractional, mid-animation) number for display. Default: rounds. */
  format?: (n: number) => string;
  /** D-W0.13's --dur-count is 600ms; passed as a prop rather than read from
   *  the CSS variable so this stays a plain rAF loop with no layout read. */
  durationMs?: number;
  className?: string;
}

/**
 * A hero/tile number that counts from its *previous* shown value to a new
 * one (D-W0.13) — never from zero on a TanStack refetch. The first render
 * shows the value directly (nothing to count up from yet); a value that
 * doesn't change never starts a rAF loop at all; reduced motion jumps
 * straight to the final value; a value that changes again mid-animation
 * continues from wherever the animation currently is, not from the original
 * start (so a fast double refetch doesn't visibly rewind).
 */
export function AnimatedNumber({ value, format = (n) => String(Math.round(n)), durationMs = 600, className }: AnimatedNumberProps) {
  const reducedMotion = useReducedMotion();
  const [display, setDisplay] = useState(value);
  const shownValueRef = useRef(value);
  const liveValueRef = useRef(value);
  const hasRenderedRef = useRef(false);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    if (!hasRenderedRef.current) {
      // `useState(value)` already shows the right number — nothing to set.
      hasRenderedRef.current = true;
      shownValueRef.current = value;
      liveValueRef.current = value;
      return;
    }

    const from = shownValueRef.current;
    const to = value;
    if (from === to) return; // an equal value never starts a rAF loop

    if (reducedMotion) {
      shownValueRef.current = to;
      liveValueRef.current = to;
      // One rAF tick, not a synchronous set in the effect body — still
      // "the final value on the first frame" (D-W0.13), just not before any
      // frame has painted at all.
      rafRef.current = requestAnimationFrame(() => setDisplay(to));
      return () => {
        if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
      };
    }

    const start = performance.now();
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / durationMs);
      const current = from + (to - from) * t;
      liveValueRef.current = current;
      setDisplay(current);
      if (t < 1) {
        rafRef.current = requestAnimationFrame(tick);
      } else {
        shownValueRef.current = to;
      }
    };
    rafRef.current = requestAnimationFrame(tick);

    return () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
      // A new value arrived mid-flight: pick up from here, not from `from`.
      shownValueRef.current = liveValueRef.current;
    };
  }, [value, reducedMotion, durationMs]);

  return (
    <span className={["num tabular", className].filter(Boolean).join(" ")}>{format(display)}</span>
  );
}
