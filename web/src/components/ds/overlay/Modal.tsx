"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { useFocusTrap } from "@/lib/a11y/useFocusTrap";
import { useFocusReturn } from "@/lib/a11y/useFocusReturn";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { getOverlayContainer } from "./OverlayRoot";
import { Sheet } from "./Sheet";

export interface ModalProps {
  open: boolean;
  onClose: () => void;
  /** 480 / 640 / 880 (D-W0.12). */
  width?: 480 | 640 | 880;
  "aria-label"?: string;
  children: ReactNode;
  className?: string;
}

/**
 * A short-decision overlay (D-W0.15) — centred, `--r-hero`, `--modal-bg`
 * (`--nested` dark / white light), 40% scrim, 200ms scale-in. Focus is
 * trapped and returned, Esc cancels, the page behind doesn't scroll. Under
 * 768px this renders as the bottom `Sheet` instead (D-W0.13's mobile shape).
 */
export function Modal({ open, onClose, width = 480, children, className, ...aria }: ModalProps) {
  const panelRef = useRef<HTMLDivElement>(null);
  const isMobile = useMediaQuery("(max-width: 767px)");
  // Must run before useFocusTrap: it captures document.activeElement, and
  // the trap's own effect immediately moves focus into the dialog — if the
  // trap ran first, this would capture the dialog's own focused child
  // instead of the trigger that opened it.
  useFocusReturn(open);
  useFocusTrap(open, panelRef);

  useEffect(() => {
    if (!open) return;
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", handleKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKey);
      document.body.style.overflow = prevOverflow;
    };
  }, [open, onClose]);

  if (!open || typeof document === "undefined") return null;

  if (isMobile) {
    return createPortal(
      <Sheet ref={panelRef} onScrimClick={onClose} aria-label={aria["aria-label"]}>
        {children}
      </Sheet>,
      getOverlayContainer(),
    );
  }

  return createPortal(
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center p-4"
      style={{ background: "var(--modal-scrim)", animation: "lifey-scrim-enter var(--dur-modal) var(--ease-standard)" }}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-label={aria["aria-label"]}
        tabIndex={-1}
        className={["w-full overflow-y-auto", className].filter(Boolean).join(" ")}
        style={{
          maxWidth: width,
          maxHeight: "85vh",
          background: "var(--modal-bg)",
          borderRadius: "var(--r-hero)",
          boxShadow: "var(--e2)",
          animation: "lifey-modal-enter var(--dur-modal) var(--ease-enter)",
        }}
      >
        {children}
      </div>
    </div>,
    getOverlayContainer(),
  );
}
