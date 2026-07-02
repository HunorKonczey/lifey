"use client";

import { useTranslations } from "next-intl";

interface HeroMetricCardProps {
  value: number;
  goal: number;
  unit?: string;
}

export function HeroMetricCard({ value, goal, unit = "kcal" }: HeroMetricCardProps) {
  const t = useTranslations("dashboard");
  const ratio = goal > 0 ? Math.min(value / goal, 1) : 0;
  const over = value > goal;
  const diff = Math.abs(Math.round(value - goal));
  const progressColor = over ? "var(--goal-negative)" : "var(--metric-kcal)";

  return (
    <div
      className="rounded-[var(--r-lg)] p-6"
      style={{ background: "var(--surface)" }}
    >
      {/* Header */}
      <div className="flex items-center gap-2 mb-4">
        <span
          className="material-symbols-rounded text-xl"
          style={{ color: "var(--metric-kcal)", fontVariationSettings: "'FILL' 1" }}
        >
          local_fire_department
        </span>
        <span className="text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          {t("calories")}
        </span>
        <div className="ml-auto">
          <span
            className="px-2 py-0.5 rounded-[var(--r-pill)] text-xs font-bold"
            style={{
              background: over
                ? "color-mix(in srgb, var(--goal-negative) 15%, transparent)"
                : "color-mix(in srgb, var(--goal-positive) 15%, transparent)",
              color: over ? "var(--goal-negative)" : "var(--goal-positive)",
            }}
          >
            {over ? t("over", { diff, unit }) : t("onTrack")}
          </span>
        </div>
      </div>

      {/* Big number */}
      <div className="flex items-end gap-2 mb-4">
        <span className="tabular font-extrabold" style={{ fontSize: 46, lineHeight: 1, color: "var(--on-surface)" }}>
          {Math.round(value).toLocaleString()}
        </span>
        <span className="text-base font-semibold mb-1" style={{ color: "var(--on-surface-variant)" }}>
          / {goal.toLocaleString()} {unit}
        </span>
      </div>

      {/* Progress bar */}
      <div
        className="h-2 rounded-[var(--r-pill)] overflow-hidden"
        style={{ background: "var(--surface-highest)" }}
      >
        <div
          className="h-full rounded-[var(--r-pill)] transition-all duration-[var(--dur-slow)]"
          style={{ width: `${ratio * 100}%`, background: progressColor }}
        />
      </div>

      {!over && (
        <p className="mt-2 text-xs tabular" style={{ color: "var(--on-surface-variant)" }}>
          {t("remaining", { diff, unit })}
        </p>
      )}
    </div>
  );
}
