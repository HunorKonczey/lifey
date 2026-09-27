"use client";

import { useEffect, useRef } from "react";

/** Calls `onEscape` when Escape is pressed while `active` — the keyboard way out of an overlay. */
export function useEscapeKey(onEscape: () => void, active = true) {
  // Kept in a ref so callers can pass an inline arrow without re-subscribing every render.
  const handler = useRef(onEscape);
  useEffect(() => {
    handler.current = onEscape;
  });

  useEffect(() => {
    if (!active) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") handler.current();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [active]);
}
