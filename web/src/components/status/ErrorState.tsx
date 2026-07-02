"use client";

import { useTranslations } from "next-intl";

interface ErrorStateProps {
  message?: string;
  onRetry?: () => void;
  inline?: boolean;
}

export function ErrorState({
  message,
  onRetry,
  inline = false,
}: ErrorStateProps) {
  const t = useTranslations("status");
  const common = useTranslations("common");
  const resolvedMessage = message ?? t("errorBody");

  if (inline) {
    return (
      <div
        className="flex items-center gap-3 px-4 py-3 rounded-[var(--r-card)] text-sm"
        style={{ background: "color-mix(in srgb, var(--error) 12%, transparent)", border: "1px solid color-mix(in srgb, var(--error) 30%, transparent)" }}
      >
        <span
          className="material-symbols-rounded text-xl shrink-0"
          style={{ color: "var(--error)", fontVariationSettings: "'FILL' 1" }}
        >
          error
        </span>
        <span className="flex-1" style={{ color: "var(--on-surface)" }}>{resolvedMessage}</span>
        {onRetry && (
          <button
            onClick={onRetry}
            className="shrink-0 text-sm font-semibold"
            style={{ color: "var(--error)" }}
          >
            {common("retry")}
          </button>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center gap-4 py-16 text-center">
      <div
        className="w-16 h-16 rounded-full flex items-center justify-center"
        style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)" }}
      >
        <span
          className="material-symbols-rounded text-3xl"
          style={{ color: "var(--error)", fontVariationSettings: "'FILL' 1" }}
        >
          cloud_off
        </span>
      </div>
      <div>
        <p className="font-bold text-base mb-1">{t("errorTitle")}</p>
        <p className="text-sm max-w-xs" style={{ color: "var(--on-surface-variant)" }}>
          {resolvedMessage}
        </p>
      </div>
      {onRetry && (
        <button
          onClick={onRetry}
          className="px-5 py-2 rounded-[var(--r-input)] text-sm font-semibold transition-opacity hover:opacity-80"
          style={{ background: "var(--surface-high)", border: "1px solid var(--outline)" }}
        >
          {common("tryAgain")}
        </button>
      )}
    </div>
  );
}
