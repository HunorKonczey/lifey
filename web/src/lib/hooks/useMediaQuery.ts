"use client";

import { useCallback, useSyncExternalStore } from "react";

/**
 * SSR-safe media query hook. `useSyncExternalStore`'s server snapshot is
 * always `false`, so the hydration render always matches the server's —
 * unlike a `useState(() => window.matchMedia(...).matches)` lazy initializer,
 * which reads the real (possibly-mobile) value on the client's first render
 * and silently mismatches server-rendered markup that assumed desktop. React
 * resyncs to the true value right after hydration, with no warning.
 */
export function useMediaQuery(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      const mql = window.matchMedia(query);
      mql.addEventListener("change", onChange);
      return () => mql.removeEventListener("change", onChange);
    },
    [query],
  );
  const getSnapshot = useCallback(() => window.matchMedia(query).matches, [query]);
  const getServerSnapshot = () => false;

  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}
