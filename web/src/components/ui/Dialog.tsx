"use client";

import { useEffect } from "react";
import { createPortal } from "react-dom";

interface DialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}

/** Centered modal overlay — backdrop click and Escape both close it. */
export function Dialog({ open, onClose, title, children }: DialogProps) {
  useEffect(() => {
    if (!open) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onClose]);

  if (!open) return null;

  // The backdrop itself scrolls (rather than capping the card's height with
  // a vh unit and scrolling inside it) — on mobile browsers, vh is measured
  // against the viewport with the address bar collapsed, so a fixed-position
  // element sized off it can end up with its painted position and its
  // hit-test/scroll geometry out of sync as the address bar shows/hides,
  // which made the bottom-row buttons in taller dialogs unreliable to tap.
  return createPortal(
    <div
      className="fixed inset-0 z-50 overflow-y-auto"
      style={{ background: "rgba(0, 0, 0, 0.5)" }}
      onClick={onClose}
    >
      <div className="min-h-full flex items-center justify-center p-4">
        <div
          role="dialog"
          aria-modal="true"
          aria-label={title}
          onClick={(e) => e.stopPropagation()}
          className="w-full max-w-md rounded-[var(--r-lg)] p-6"
          style={{ background: "var(--surface)", border: "1px solid var(--outline)" }}
        >
          <h2 className="text-lg font-bold mb-4">{title}</h2>
          {children}
        </div>
      </div>
    </div>,
    document.body,
  );
}
