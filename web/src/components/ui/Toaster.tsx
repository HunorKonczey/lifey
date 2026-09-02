"use client";

import { useTranslations } from "next-intl";
import { useToast, type ToastVariant } from "@/lib/hooks/useToast";

// `fg` only where the background flips with the theme: --goal-positive is a
// pale green in the dark theme but a dark one in the light theme, so a fixed
// near-black on it drops to ~3:1 there. --error and --metric-kcal are the
// same light tones in both themes and keep the near-black.
const VARIANT_STYLES: Record<ToastVariant, { bg: string; fg: string; icon: string }> = {
  default: { bg: "var(--surface-high)", fg: "var(--on-surface)", icon: "info" },
  success: { bg: "var(--goal-positive)", fg: "var(--bg)", icon: "check_circle" },
  error: { bg: "var(--error)", fg: "#1E1F18", icon: "error" },
  warning: { bg: "var(--metric-kcal)", fg: "#1E1F18", icon: "warning" },
};

export function Toaster() {
  const t = useTranslations("common");
  const { toasts, dismiss } = useToast();

  if (toasts.length === 0) return null;

  return (
    <div
      className="fixed bottom-6 right-6 z-50 flex flex-col gap-2 pointer-events-none"
      aria-live="polite"
    >
      {toasts.map((toast) => {
        const { bg, fg, icon } = VARIANT_STYLES[toast.variant];
        const isColored = toast.variant !== "default";
        return (
          <div
            key={toast.id}
            className="pointer-events-auto flex items-center gap-3 px-4 py-3 rounded-[var(--r-card)] shadow-lg text-sm font-semibold max-w-sm"
            style={{
              background: bg,
              color: fg,
              border: isColored ? "none" : "1px solid var(--outline)",
              animation: "slideIn var(--dur-base) var(--ease)",
            }}
          >
            <span className="material-symbols-rounded text-xl shrink-0" style={{ fontVariationSettings: "'FILL' 1" }}>
              {icon}
            </span>
            <span className="flex-1">{toast.message}</span>
            <button
              onClick={() => dismiss(toast.id)}
              className="shrink-0 opacity-70 hover:opacity-100 transition-opacity"
              aria-label={t("close")}
            >
              <span className="material-symbols-rounded text-lg">close</span>
            </button>
          </div>
        );
      })}
      <style>{`
        @keyframes slideIn {
          from { opacity: 0; transform: translateY(8px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  );
}
