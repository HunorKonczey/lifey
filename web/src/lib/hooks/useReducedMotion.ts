"use client";

import { useMediaQuery } from "./useMediaQuery";

export const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)";

/** Non-reactive read for one-off checks outside a component (e.g. a Recharts
 *  `isAnimationActive` computed once at chart construction, D-W0.9/D-W0.13).
 *  `false` on the server and before the client can evaluate the query. */
export function prefersReducedMotion(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia(REDUCED_MOTION_QUERY).matches;
}

/** Reactive `prefers-reduced-motion` — re-renders if the user flips the OS
 *  setting while the page is open (D-W0.13). */
export function useReducedMotion(): boolean {
  return useMediaQuery(REDUCED_MOTION_QUERY);
}
