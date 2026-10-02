"use client";

import { useEffect, type RefObject } from "react";

/** Esc key or a click/tap outside `containerRef` closes an open overlay
 *  (D-W0.11) — shared by Popover, Menu, and every later overlay. */
export function useDismiss(active: boolean, onDismiss: () => void, containerRef: RefObject<HTMLElement | null>) {
  useEffect(() => {
    if (!active) return;

    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") onDismiss();
    }
    function handlePointerDown(e: PointerEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) onDismiss();
    }

    document.addEventListener("keydown", handleKey);
    document.addEventListener("pointerdown", handlePointerDown);
    return () => {
      document.removeEventListener("keydown", handleKey);
      document.removeEventListener("pointerdown", handlePointerDown);
    };
  }, [active, onDismiss, containerRef]);
}
