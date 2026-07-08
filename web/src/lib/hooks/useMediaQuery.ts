"use client";

import { useEffect, useState } from "react";

/** SSR-safe media query hook — `false` (desktop-first default) until the client
 *  can evaluate the query; the lazy initializer covers the first client render
 *  so there's no extra effect-driven re-render on mount. */
export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(() => (typeof window !== "undefined" ? window.matchMedia(query).matches : false));

  useEffect(() => {
    const mql = window.matchMedia(query);
    const onChange = () => setMatches(mql.matches);
    mql.addEventListener("change", onChange);
    return () => mql.removeEventListener("change", onChange);
  }, [query]);

  return matches;
}
