"use client";

import { useRef, type ReactNode, type RefObject } from "react";
import { createPortal } from "react-dom";
import { useAnchoredPosition } from "@/lib/a11y/useAnchoredPosition";
import { useDismiss } from "@/lib/a11y/useDismiss";
import { useFocusReturn } from "@/lib/a11y/useFocusReturn";
import { getOverlayContainer } from "./overlay/OverlayRoot";

export interface PopoverProps {
  open: boolean;
  onClose: () => void;
  anchorRef: RefObject<HTMLElement | null>;
  width?: number;
  children: ReactNode;
  className?: string;
}

/**
 * A floating panel anchored to a trigger (D-W0.11/D-W0.15) — 160ms open,
 * flips above near the bottom edge, closes on Esc and an outside click,
 * returns focus to its trigger. Portals into the shared `OverlayRoot`
 * (D-W0.15's z-order: toast > modal > drawer > popover > top bar).
 */
export function Popover({ open, onClose, anchorRef, width = 280, children, className }: PopoverProps) {
  const panelRef = useRef<HTMLDivElement>(null);
  const { top, bottom, left, placement } = useAnchoredPosition(anchorRef, open, width);
  useDismiss(open, onClose, panelRef);
  useFocusReturn(open);

  if (!open || typeof document === "undefined") return null;

  return createPortal(
    <div
      ref={panelRef}
      className={["fixed z-50 overflow-hidden", className].filter(Boolean).join(" ")}
      style={{
        ...(placement === "bottom" ? { top } : { bottom }),
        left,
        width,
        background: "var(--card)",
        borderRadius: "var(--r-card)",
        boxShadow: "var(--e2)",
        animation: `lifey-popover-${placement === "bottom" ? "enter-down" : "enter-up"} var(--dur-menu) var(--ease-enter)`,
      }}
    >
      {children}
    </div>,
    getOverlayContainer(),
  );
}
