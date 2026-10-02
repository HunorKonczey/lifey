"use client";

import { useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import type { StepsWindow } from "../stats";

function Stat({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <Card className="flex flex-col gap-1">
      <span className="type-label" style={{ color: "var(--text-3)" }}>
        {label}
      </span>
      <span className="tabular" style={{ fontSize: 24, fontWeight: 800, letterSpacing: "-0.02em" }}>
        {value}
      </span>
      {sub && (
        <span className="type-body-s" style={{ color: "var(--text-2)" }}>
          {sub}
        </span>
      )}
    </Card>
  );
}

/** The three stat cards beside the hero (W4.6): 14-day average, goal days out of the complete ones, the best day. */
export function StepsStats({ stats, showGoal = true }: { stats: StepsWindow; showGoal?: boolean }) {
  const t = useTranslations("steps");
  const fmt = useFormat();

  return (
    <>
      <Stat label={t("statAverage")} value={stats.average != null ? fmt.integer(stats.average) : "—"} />
      {showGoal && <Stat label={t("statMet")} value={t("statMetValue", { met: stats.metDays, total: stats.completeDays })} />}
      <Stat label={t("statBest")} value={stats.best ? fmt.integer(stats.best.steps) : "—"} sub={stats.best ? fmt.shortDate(stats.best.date) : undefined} />
    </>
  );
}
