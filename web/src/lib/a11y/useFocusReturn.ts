"use client";

import { useEffect, useRef } from "react";

/** Remembers whatever had focus when an overlay opened and gives it back
 *  when the overlay closes (D-W0.11/D-W0.12) — a menu, popover, modal, or
 *  drawer never strands keyboard focus on a removed trigger. */
export function useFocusReturn(active: boolean) {
  const previouslyFocused = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (active) {
      previouslyFocused.current = document.activeElement as HTMLElement | null;
    } else {
      previouslyFocused.current?.focus();
    }
  }, [active]);
}
