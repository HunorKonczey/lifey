"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { useTranslations } from "next-intl";
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
  /** Under the title — e.g. an "unsaved change" chip (beside it, a long title would be cut off). */
  badge?: ReactNode;
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
  badge,
  children,
  ...aria
}: DrawerProps) {
  const common = useTranslations("common");
  const panelRef = useRef<HTMLDivElement>(null);
  const isMobile = useMediaQuery("(max-width: 767px)");
  const guard = useUnsavedGuard(isDirty, onClose);

  useFocusReturn(open);
  useFocusTrap(open, panelRef);

  // The Esc listener is attached once per open, so it must reach the *current* guard: changes made
  // after the drawer opened (the usual case for a form) flip `isDirty`, and a stale one would close
  // a dirty drawer outright.
  const requestCloseRef = useRef(guard.requestClose);
  useEffect(() => {
    requestCloseRef.current = guard.requestClose;
  });

  useEffect(() => {
    if (!open) return;
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") requestCloseRef.current();
    }
    document.addEventListener("keydown", handleKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKey);
      document.body.style.overflow = prevOverflow;
    };
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
        {badge && <div className="mt-1.5">{badge}</div>}
      </div>
      <IconButton icon="close" label={common("close")} size={40} tooltipPlacement="below-end" onClick={() => guard.requestClose()} />
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
        title={common("discardChangesTitle")}
        body={common("discardChangesBody")}
        confirmLabel={common("discardConfirm")}
        cancelLabel={common("keepEditing")}
      />
    </>,
    getOverlayContainer(),
  );
}
