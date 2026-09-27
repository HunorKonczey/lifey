"use client";

import { useEffect, useState } from "react";

function read(name: string): string {
  if (typeof window === "undefined") return "";
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

/**
 * The live, browser-resolved value of a `:root` custom property — re-reads
 * whenever `data-theme`/`data-surface` change, so the design gallery's
 * swatches (W0.5) always show what the current theme actually renders,
 * never a hard-coded palette table that can drift from `globals.css`.
 */
export function useCssVar(name: string): string {
  const [value, setValue] = useState(() => read(name));

  useEffect(() => {
    const update = () => setValue(read(name));
    update();
    const observer = new MutationObserver(update);
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme", "data-surface", "data-force-reduced-motion"],
    });
    return () => observer.disconnect();
  }, [name]);

  return value;
}
