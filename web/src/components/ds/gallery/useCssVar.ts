"use client";

import { useEffect, useState } from "react";

function read(name: string): string {
  if (typeof window === "undefined") return "";
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

/**
 * The live, browser-resolved value of a `:root` custom property — re-reads
 * whenever `data-theme` changes, so the design gallery's
 * swatches (W0.5) always show what the current theme actually renders,
 * never a hard-coded palette table that can drift from `globals.css`.
 *
 * Always starts `""` (not `read(name)` eagerly) so the first client render
 * matches the server's: `getComputedStyle` genuinely doesn't exist during
 * SSR, but a lazy initializer runs during hydration too, where `window`
 * *does* exist — reading the real value there instead of after mount is a
 * same-render-different-answer hydration mismatch, not a deferred one.
 */
export function useCssVar(name: string): string {
  const [value, setValue] = useState("");

  useEffect(() => {
    const update = () => setValue(read(name));
    update();
    const observer = new MutationObserver(update);
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme", "data-force-reduced-motion"],
    });
    return () => observer.disconnect();
  }, [name]);

  return value;
}
