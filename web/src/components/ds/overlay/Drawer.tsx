"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { useFocusReturn } from "@/lib/a11y/useFocusReturn";
import { useFocusTrap } from "@/lib/a11y/useFocusTrap";
import { useUnsavedGuard } from "@/lib/a11y/useUnsavedGuard";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { IconButton } from "../IconButton";
import { ConfirmModal } from "./ConfirmModal";
import { getOverlayContainer } from "./OverlayRoot";
import { Sheet } from "./Sheet";

export interface DrawerProps {
  open: boolean;
  onClose: () => void;
  /** 480 / 520 / 560 (D-W0.13). */
  width?: 480 | 520 | 560;
  overline?: string;
  title: string;
  /** True while the drawer holds unsaved input — Esc, a scrim click, and
   *  the header × then ask via `ConfirmModal` instead of closing outright. */
  isDirty?: boolean;
  /** The sticky footer's own secondary + primary `Button`s. */
  footer?: ReactNode;
  children: ReactNode;
  "aria-label"?: string;
}

/**
 * A longer-form side panel (D-W0.13) — from the right, `--r-hero` on the
 * inner edge, sticky header (overline + title + close) and footer. Focus is
 * trapped and returned, Esc/scrim/× ask first when `isDirty` (the recorded
 * `trainer-011` bug was a schedule drawer that didn't close on either).
 * Under 768px this renders as a full-height `Sheet`.
 */
export function Drawer({
  open,
  onClose,
  width = 480,
  overline,
  title,
  isDirty = false,
  footer,
  children,
  ...aria
}: DrawerProps) {
  const panelRef = useRef<HTMLDivElement>(null);
  const isMobile = useMediaQuery("(max-width: 767px)");
  const guard = useUnsavedGuard(isDirty, onClose);

  useFocusReturn(open);
  useFocusTrap(open, panelRef);

  useEffect(() => {
    if (!open) return;
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") guard.requestClose();
    }
    document.addEventListener("keydown", handleKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKey);
      document.body.style.overflow = prevOverflow;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- guard.requestClose closes over isDirty/onClose directly
  }, [open]);

  if (!open || typeof document === "undefined") return null;

  const label = aria["aria-label"] ?? title;
  const header = (
    <div
      className="flex items-start justify-between gap-3 px-6 py-4 shrink-0"
      style={{ borderBottom: "1px solid var(--hairline)" }}
    >
      <div className="min-w-0">
        {overline && (
          <div className="type-overline truncate" style={{ color: "var(--text-3)" }}>
            {overline}
          </div>
        )}
        <h2 className="type-title-l truncate">{title}</h2>
      </div>
      <IconButton icon="close" label="Close" size={40} onClick={() => guard.requestClose()} />
    </div>
  );
  const body = <div className="flex-1 overflow-y-auto px-6 py-4">{children}</div>;
  const footerEl = footer && (
    <div
      className="flex items-center justify-end gap-3 px-6 py-4 shrink-0"
      style={{ borderTop: "1px solid var(--hairline)" }}
    >
      {footer}
    </div>
  );

  return createPortal(
    <>
      {isMobile ? (
        <Sheet ref={panelRef} onScrimClick={() => guard.requestClose()} aria-label={label} fullHeight>
          {header}
          {body}
          {footerEl}
        </Sheet>
      ) : (
        <div
          className="fixed inset-0 z-[60] flex justify-end"
          style={{ background: "var(--modal-scrim)", animation: "lifey-scrim-enter var(--dur-drawer) var(--ease-standard)" }}
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) guard.requestClose();
          }}
        >
          <div
            ref={panelRef}
            role="dialog"
            aria-modal="true"
            aria-label={label}
            tabIndex={-1}
            className="h-full flex flex-col overflow-hidden"
            style={{
              width,
              background: "var(--modal-bg)",
              borderTopLeftRadius: "var(--r-hero)",
              borderBottomLeftRadius: "var(--r-hero)",
              boxShadow: "var(--e2)",
              animation: "lifey-drawer-enter var(--dur-drawer) var(--ease-enter)",
            }}
          >
            {header}
            {body}
            {footerEl}
          </div>
        </div>
      )}
      <ConfirmModal
        open={guard.confirmOpen}
        onClose={guard.cancelDiscard}
        onConfirm={guard.confirmDiscard}
        title="Discard changes?"
        body="Your changes haven't been saved."
        confirmLabel="Discard"
        cancelLabel="Keep editing"
      />
    </>,
    getOverlayContainer(),
  );
}
