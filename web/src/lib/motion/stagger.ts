import { prefersReducedMotion } from "@/lib/hooks/useReducedMotion";

const STAGGER_MS = 60;

/**
 * Per-index entrance delay for a group of elements animating in together —
 * D-W0.13's 60ms stagger (a row of tiles filling in one after another).
 * Always 0 under reduced motion, so nothing waits to "finish" a stagger that
 * isn't actually happening.
 */
export function staggerDelay(index: number, stepMs: number = STAGGER_MS): number {
  if (prefersReducedMotion()) return 0;
  return index * stepMs;
}
