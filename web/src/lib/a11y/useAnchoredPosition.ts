"use client";

import { useLayoutEffect, useState, type RefObject } from "react";

export interface AnchoredPosition {
  /** Set when placed below the trigger. */
  top: number;
  /** Set when flipped above: pinned by its bottom edge, so the gap to the
   *  trigger holds whatever height the panel really has (not the estimate
   *  `panelHeight` is only used to decide *whether* to flip). */
  bottom: number;
  left: number;
  placement: "bottom" | "top";
}

/**
 * Positions a floating panel against its trigger (D-W0.11) — flips above
 * when there isn't room below, and clamps horizontally so it never runs off
 * the viewport at 390px. Recomputes on open, resize, and scroll (capture,
 * so scrolling any ancestor — not just the window — repositions it).
 */
export function useAnchoredPosition(
  anchorRef: RefObject<HTMLElement | null>,
  open: boolean,
  panelWidth = 280,
  panelHeight = 240,
): AnchoredPosition {
  const [pos, setPos] = useState<AnchoredPosition>({ top: 0, bottom: 0, left: 0, placement: "bottom" });

  useLayoutEffect(() => {
    if (!open || !anchorRef.current) return;

    function update() {
      const rect = anchorRef.current!.getBoundingClientRect();
      const spaceBelow = window.innerHeight - rect.bottom;
      const placement: "bottom" | "top" = spaceBelow < panelHeight && rect.top > panelHeight ? "top" : "bottom";
      const top = rect.bottom + 4;
      const bottom = window.innerHeight - rect.top + 4;
      const left = Math.min(Math.max(8, rect.left), window.innerWidth - panelWidth - 8);
      setPos({ top, bottom, left, placement });
    }

    update();
    window.addEventListener("resize", update);
    window.addEventListener("scroll", update, true);
    return () => {
      window.removeEventListener("resize", update);
      window.removeEventListener("scroll", update, true);
    };
  }, [open, anchorRef, panelWidth, panelHeight]);

  return pos;
}
