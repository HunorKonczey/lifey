"use client";

import { useEffect, useState } from "react";
import { useMediaQuery } from "./useMediaQuery";

export const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)";
const FORCE_ATTR = "data-force-reduced-motion";
const FORCE_EVENT = "lifey:force-reduced-motion";

function isForced(): boolean {
  return typeof document !== "undefined" && document.documentElement.getAttribute(FORCE_ATTR) === "true";
}

/** Dev-only escape hatch for the design gallery's toolbar (W0.5): forces
 *  every consumer of reduced motion into that state — both the CSS block in
 *  globals.css and this hook — without touching the host machine's OS
 *  setting. Dispatches a same-tab event so `useReducedMotion` re-renders
 *  immediately (a plain attribute change fires no DOM event on its own). */
export function setForcedReducedMotion(forced: boolean) {
  document.documentElement.setAttribute(FORCE_ATTR, String(forced));
  window.dispatchEvent(new Event(FORCE_EVENT));
}

/** Non-reactive read for one-off checks outside a component (e.g. a Recharts
 *  `isAnimationActive` computed once at chart construction, D-W0.9/D-W0.13).
 *  `false` on the server and before the client can evaluate the query. */
export function prefersReducedMotion(): boolean {
  if (typeof window === "undefined") return false;
  return isForced() || window.matchMedia(REDUCED_MOTION_QUERY).matches;
}

/** Reactive `prefers-reduced-motion` — re-renders if the user flips the OS
 *  setting, or the gallery's forced toggle, while the page is open (D-W0.13). */
export function useReducedMotion(): boolean {
  const media = useMediaQuery(REDUCED_MOTION_QUERY);
  const [forced, setForced] = useState(isForced);

  useEffect(() => {
    const onChange = () => setForced(isForced());
    window.addEventListener(FORCE_EVENT, onChange);
    return () => window.removeEventListener(FORCE_EVENT, onChange);
  }, []);

  return media || forced;
}
