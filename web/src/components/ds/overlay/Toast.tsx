"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Icon } from "../Icon";
import { TOAST_DURATION_MS, useToast, type ToastRecord, type ToastVariant } from "@/lib/hooks/useToast";

const ICONS: Record<ToastVariant, string> = {
  default: "info",
  success: "check_circle",
  error: "error",
  warning: "warning",
};

/**
 * Bottom-centre, one at a time, inverse surface fixed to the v2 **dark**
 * palette in both themes (D-W0.14). Non-sticky toasts show a 6 s linear bar
 * that pauses on hover/focus; the error variant is sticky with a close
 * button instead. Route changes and `pagehide` both flush whatever undo
 * commit is still pending (D-W0.16) rather than leaving it stranded.
 */
export function Toast() {
  const toast = useToast((s) => s.toast);
  const pathname = usePathname();
  const mountedPathname = useRef(pathname);

  useEffect(() => {
    if (mountedPathname.current !== pathname) {
      mountedPathname.current = pathname;
      useToast.getState().dismiss();
    }
  }, [pathname]);

  useEffect(() => {
    function handlePageHide() {
      useToast.getState().dismiss();
    }
    window.addEventListener("pagehide", handlePageHide);
    return () => window.removeEventListener("pagehide", handlePageHide);
  }, []);

  if (!toast) return null;

  return (
    <div
      className="fixed left-1/2 -translate-x-1/2 z-[60] pointer-events-none px-4"
      style={{ bottom: "calc(24px + env(safe-area-inset-bottom))" }}
    >
      {/* Keyed on the toast's id so a new toast always mounts fresh —
          `paused` and the bar's animation both restart cleanly instead of
          carrying over from whatever the previous toast was doing. */}
      <ToastCard key={toast.id} toast={toast} />
    </div>
  );
}

function ToastCard({ toast }: { toast: ToastRecord }) {
  const t = useTranslations("common");
  const [paused, setPaused] = useState(false);

  function pause() {
    setPaused(true);
    useToast.getState().pause();
  }
  function resume() {
    setPaused(false);
    useToast.getState().resume();
  }

  return (
    <div
      role="status"
      aria-live={toast.variant === "error" ? "assertive" : "polite"}
      onMouseEnter={pause}
      onMouseLeave={resume}
      onFocus={pause}
      onBlur={resume}
      className="pointer-events-auto relative flex items-center gap-3 pl-4 pr-3 max-w-[calc(100vw-32px)] overflow-hidden"
      style={{
        height: 52,
        borderRadius: "var(--r-control)",
        background: "var(--toast-bg)",
        color: "var(--toast-fg)",
        boxShadow: "var(--e2)",
        animation: "lifey-toast-enter var(--dur-toast) var(--ease-enter)",
      }}
    >
      <Icon name={ICONS[toast.variant]} fill={1} size={20} />
      <span className="type-body-s truncate">{toast.message}</span>
      {toast.onUndo && (
        <button
          type="button"
          onClick={() => useToast.getState().undo()}
          className="lifey-button shrink-0 type-button-dense px-2 h-8 rounded-[var(--r-tag)]"
          style={{ color: "var(--toast-fg)" }}
        >
          {t("undo")}
        </button>
      )}
      {toast.sticky && (
        <button
          type="button"
          onClick={() => useToast.getState().dismiss()}
          aria-label={t("close")}
          className="lifey-button shrink-0 inline-flex items-center justify-center w-8 h-8 rounded-full"
          style={{ color: "var(--toast-fg)" }}
        >
          <Icon name="close" size={18} />
        </button>
      )}
      {!toast.sticky && (
        <div
          className="absolute left-0 bottom-0 h-[3px] w-full origin-left"
          style={{
            background: "var(--primary)",
            animation: `lifey-toast-bar ${TOAST_DURATION_MS}ms linear forwards`,
            animationPlayState: paused ? "paused" : "running",
          }}
        />
      )}
    </div>
  );
}
