"use client";

import { useTranslations } from "next-intl";
import { useFormat } from "@/lib/format/useFormat";
import type { FiberSugarTotals } from "../fiberSugar";

/**
 * "Fibre 12 g · Sugar 5 g" under a meal's foods or the day's macros (LIF-145) - nothing when no food has a figure, and a
 * "some foods have none" note when only some do, so a partial sum is not mistaken for the whole.
 */
export function FiberSugarLine({ totals, testId, className }: { totals: FiberSugarTotals; testId: string; className?: string }) {
  const t = useTranslations("nutrition");
  const fmt = useFormat();
  const parts = [
    totals.fiber != null ? t("fiberTotal", { value: fmt.number(totals.fiber, 1) }) : null,
    totals.sugar != null ? t("sugarTotal", { value: fmt.number(totals.sugar, 1) }) : null,
  ].filter(Boolean);
  if (parts.length === 0) return null;
  return (
    <p className={`type-body-s tabular ${className ?? ""}`} data-testid={testId} style={{ color: "var(--text-3)" }}>
      {parts.join(" · ")}
      {totals.partial ? ` · ${t("fiberSugarPartial")}` : ""}
    </p>
  );
}
