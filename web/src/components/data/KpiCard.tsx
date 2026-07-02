"use client";

import { useTranslations } from "next-intl";

interface KpiCardProps {
  label: string;
  value: string;
  icon: string;
  color: string;
  delta?: number | null;
  /** If true, a positive delta is "good" (green); if false, negative is good. */
  higherIsBetter?: boolean;
  deltaUnit?: string;
}

export function KpiCard({
  label, value, icon, color, delta, higherIsBetter = true, deltaUnit = "",
}: KpiCardProps) {
  const t = useTranslations("common");
  const hasDelta = delta != null && delta !== 0;
  const good = delta != null && (higherIsBetter ? delta > 0 : delta < 0);

  return (
    <div className="flex flex-col gap-2 p-4 rounded-[var(--r-card)]" style={{ background: "var(--surface)" }}>
      <div className="flex items-center gap-2">
        <span className="material-symbols-rounded text-lg" style={{ color, fontVariationSettings: "'FILL' 1" }}>
          {icon}
        </span>
        <span className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{label}</span>
      </div>
      <span className="text-2xl font-extrabold tabular" style={{ color: "var(--on-surface)" }}>{value}</span>
      {hasDelta && (
        <div className="flex items-center gap-1 text-xs font-semibold"
          style={{ color: good ? "var(--goal-positive)" : "var(--goal-negative)" }}>
          <span className="material-symbols-rounded text-sm">
            {delta! > 0 ? "trending_up" : "trending_down"}
          </span>
          <span className="tabular">
            {delta! > 0 ? "+" : ""}{delta!.toLocaleString()}{deltaUnit} {t("vsPrevious")}
          </span>
        </div>
      )}
    </div>
  );
}
