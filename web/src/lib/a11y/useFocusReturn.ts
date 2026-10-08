"use client";

import { useEffect } from "react";

/** Remembers whatever had focus when an overlay opened and gives it back
 *  when the overlay closes (D-W0.11/D-W0.12) — a menu, popover, modal, or
 *  drawer never strands keyboard focus on a removed trigger.
 *
 *  "Closes" is the cleanup of the effect, so it covers both `active` turning
 *  false and the component unmounting while still `active` — the common
 *  `{cond && <Modal open …>}` shape, where the open flag never flips. The
 *  remembered element is skipped if it has left the document meanwhile. */
export function useFocusReturn(active: boolean) {
  useEffect(() => {
    if (!active) return;
    const previouslyFocused = document.activeElement as HTMLElement | null;
    return () => {
      if (previouslyFocused?.isConnected) previouslyFocused.focus();
    };
  }, [active]);
}
