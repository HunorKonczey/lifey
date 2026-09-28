"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@/components/ds/Button";
import { Icon } from "@/components/ds/Icon";

interface ErrorStateProps {
  message?: string;
  onRetry?: () => void;
  inline?: boolean;
  /** e.g. "workouts" — parameterizes the title into "Couldn't load workouts"
   *  instead of the generic fallback (D-W0.17). */
  entity?: string;
  /** A technical error code/message, revealed behind "Details" (D-W0.17). */
  code?: string;
}

/**
 * An error state (D-W0.17/DS-05): a heart-tinted `sync_problem` icon in a
 * heart hairline ring, a title naming what failed to load, a reassurance
 * that the rest of the app still works and nothing logged was lost, Retry,
 * and an optional "Details" toggle for the raw error code.
 */
export function ErrorState({ message, onRetry, inline = false, entity, code }: ErrorStateProps) {
  const t = useTranslations("status");
  const common = useTranslations("common");
  const [showDetails, setShowDetails] = useState(false);
  const resolvedMessage = message ?? t("errorBody");
  const title = entity ? t("errorTitleFor", { entity }) : t("errorTitle");

  if (inline) {
    return (
      <div
        className="flex flex-col gap-2 px-4 py-3 type-body-s"
        style={{
          borderRadius: "var(--r-control)",
          background: "color-mix(in srgb, var(--heart) 12%, transparent)",
          border: "1px solid color-mix(in srgb, var(--heart) 30%, transparent)",
        }}
      >
        <div className="flex items-center gap-3">
          <Icon name="sync_problem" size={20} fill={1} color="var(--heart)" className="shrink-0" />
          <span className="flex-1" style={{ color: "var(--text)" }}>
            {resolvedMessage}
          </span>
          {onRetry && (
            <button type="button" onClick={onRetry} className="lifey-button shrink-0 type-button-dense" style={{ color: "var(--heart)" }}>
              {common("retry")}
            </button>
          )}
        </div>
        {code && (
          <>
            <button
              type="button"
              onClick={() => setShowDetails((s) => !s)}
              className="lifey-button self-start type-body-s underline"
              style={{ color: "var(--text)" }}
            >
              {t("details")}
            </button>
            {showDetails && (
              <code className="type-body-s break-all" style={{ color: "var(--text)" }}>
                {code}
              </code>
            )}
          </>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center gap-4 py-16 px-4 text-center">
      <div
        className="w-16 h-16 rounded-full flex items-center justify-center shrink-0"
        style={{
          background: "color-mix(in srgb, var(--heart) var(--chip-tint), transparent)",
          boxShadow: "inset 0 0 0 1px color-mix(in srgb, var(--heart) 40%, transparent)",
        }}
      >
        <Icon name="sync_problem" size={28} fill={1} color="var(--heart)" />
      </div>
      <div>
        <p className="type-title-s mb-1">{title}</p>
        <p className="type-body-s max-w-xs" style={{ color: "var(--text-3)" }}>
          {resolvedMessage}
        </p>
        <p className="type-body-s max-w-xs mt-1" style={{ color: "var(--text-3)" }}>
          {t("errorReassurance")}
        </p>
      </div>
      <div className="flex items-center gap-3">
        {onRetry && <Button onClick={onRetry}>{common("tryAgain")}</Button>}
        {code && (
          <Button variant="ghost" onClick={() => setShowDetails((s) => !s)}>
            {t("details")}
          </Button>
        )}
      </div>
      {showDetails && code && (
        <code className="type-body-s break-all max-w-md" style={{ color: "var(--text-3)" }}>
          {code}
        </code>
      )}
    </div>
  );
}
