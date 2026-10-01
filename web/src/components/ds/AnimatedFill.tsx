"use client";

import { useEffect, useRef, useState } from "react";
import { useReducedMotion } from "@/lib/hooks/useReducedMotion";

export interface AnimatedFillProps {
  /** The fill amount — a 0–1 ratio for a ring/bar, or an absolute value the
   *  caller maps to a visual extent; this component only animates the number. */
  value: number;
  /** D-W0.13's --dur-fill (900ms): duration of the *first* appearance. */
  durationMs?: number;
  /** Entrance delay before the first animation starts — D-W0.13's 60ms
   *  stagger for a row of tiles filling in one after another. */
  delayMs?: number;
  /** Render prop: the caller draws the ring/bar from the current animated value. */
  children: (animatedValue: number) => React.ReactNode;
}

/**
 * Drives a ring or bar's fill amount (D-W0.13): animates from 0 on first
 * appearance (900ms, optionally staggered), and on every value after that
 * only the *difference* animates — never a reset back to 0. Reduced motion
 * jumps straight to the final value on the first frame.
 */
export function AnimatedFill({ value, durationMs = 900, delayMs = 0, children }: AnimatedFillProps) {
  const reducedMotion = useReducedMotion();
  // Always starts at 0 — not "reducedMotion ? value : 0" — so the very first
  // render matches server and client identically (`useReducedMotion` only
  // knows the real answer after mount); the effect below corrects to the
  // final value immediately when reduced motion is on.
  const [display, setDisplay] = useState(0);
  const shownValueRef = useRef(0);
  const liveValueRef = useRef(0);
  const hasAppearedRef = useRef(false);
  const rafRef = useRef<number | null>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const from = shownValueRef.current;
    const to = value;
    const isFirstAppearance = !hasAppearedRef.current;
    hasAppearedRef.current = true;

    if (from === to) return;

    if (reducedMotion) {
      shownValueRef.current = to;
      liveValueRef.current = to;
      // One rAF tick, not a synchronous set in the effect body.
      rafRef.current = requestAnimationFrame(() => setDisplay(to));
      return () => {
        if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
      };
    }

    const animateFrom = isFirstAppearance ? 0 : from;
    const start = () => {
      const startTime = performance.now();
      const tick = (now: number) => {
        const t = Math.min(1, (now - startTime) / durationMs);
        const current = animateFrom + (to - animateFrom) * t;
        liveValueRef.current = current;
        setDisplay(current);
        if (t < 1) {
          rafRef.current = requestAnimationFrame(tick);
        } else {
          shownValueRef.current = to;
        }
      };
      rafRef.current = requestAnimationFrame(tick);
    };

    if (isFirstAppearance && delayMs > 0) {
      // `display` is already 0 (the initial state) — nothing to set here.
      timeoutRef.current = setTimeout(start, delayMs);
    } else {
      start();
    }

    return () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
      if (timeoutRef.current !== null) clearTimeout(timeoutRef.current);
      shownValueRef.current = liveValueRef.current;
    };
  }, [value, reducedMotion, durationMs, delayMs]);

  return <>{children(display)}</>;
}
