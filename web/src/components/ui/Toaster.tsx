"use client";

import { useToast, type ToastVariant } from "@/lib/hooks/useToast";

const VARIANT_STYLES: Record<ToastVariant, { bg: string; icon: string }> = {
  default: { bg: "var(--surface-high)", icon: "info" },
  success: { bg: "var(--goal-positive)", icon: "check_circle" },
  error: { bg: "var(--error)", icon: "error" },
  warning: { bg: "var(--metric-kcal)", icon: "warning" },
};

export function Toaster() {
  const { toasts, dismiss } = useToast();

  if (toasts.length === 0) return null;

  return (
    <div
      className="fixed bottom-6 right-6 z-50 flex flex-col gap-2 pointer-events-none"
      aria-live="polite"
    >
      {toasts.map((t) => {
        const { bg, icon } = VARIANT_STYLES[t.variant];
        const isColored = t.variant !== "default";
        return (
          <div
            key={t.id}
            className="pointer-events-auto flex items-center gap-3 px-4 py-3 rounded-[var(--r-card)] shadow-lg text-sm font-semibold max-w-sm"
            style={{
              background: bg,
              color: isColored ? "#1E1F18" : "var(--on-surface)",
              border: isColored ? "none" : "1px solid var(--outline)",
              animation: "slideIn var(--dur-base) var(--ease)",
            }}
          >
            <span className="material-symbols-rounded text-xl shrink-0" style={{ fontVariationSettings: "'FILL' 1" }}>
              {icon}
            </span>
            <span className="flex-1">{t.message}</span>
            <button
              onClick={() => dismiss(t.id)}
              className="shrink-0 opacity-70 hover:opacity-100 transition-opacity"
              aria-label="Dismiss"
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
