"use client";

import { useTranslations } from "next-intl";

interface EmptyStateProps {
  icon?: string;
  title?: string;
  body?: string;
  action?: React.ReactNode;
}

export function EmptyState({
  icon = "inbox",
  title,
  body,
  action,
}: EmptyStateProps) {
  const t = useTranslations("status");
  const resolvedTitle = title ?? t("emptyTitle");
  const resolvedBody = body ?? t("emptyBody");
  return (
    <div className="flex flex-col items-center justify-center gap-4 py-16 text-center">
      <div
        className="w-16 h-16 rounded-full flex items-center justify-center"
        style={{ background: "var(--surface-highest)" }}
      >
        <span
          className="material-symbols-rounded text-3xl"
          style={{ color: "var(--on-surface-variant)", fontVariationSettings: "'FILL' 1" }}
        >
          {icon}
        </span>
      </div>
      <div>
        <p className="font-bold text-base mb-1">{resolvedTitle}</p>
        <p className="text-sm max-w-xs" style={{ color: "var(--on-surface-variant)" }}>
          {resolvedBody}
        </p>
      </div>
      {action}
    </div>
  );
}
