"use client";

import { useTranslations } from "next-intl";
import { MetricTile } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import type { Kpi, KpiDelta, PeriodStats } from "../periodStats";
import { ToneChip } from "./ToneChip";

/**
 * The six KPI tiles of W5-A (W5.3): an icon in the metric colour, the figure, a delta chip whose colour follows its
 * meaning and a context line. Six across from 1280, three by two at 768–1279, two columns at 390 showing the first
 * four (W5-D). Every figure that has nothing to stand on shows "—", and a delta that would compare with an empty
 * period shows "Nincs előző adat" instead of a number.
 */
export function KpiRow({ stats }: { stats: PeriodStats }) {
  const t = useTranslations("statistics");
  const fmt = useFormat();
  const phone = useMediaQuery("(max-width: 767px)");
  const { period, kpis } = stats;
  const valueSize = phone ? 22 : 28;
  const dash = "—";

  const signed = (amount: number, unit?: string, digits = 0) => fmt.signedDelta(amount, { digits, unit });
  const percent = (d: KpiDelta) => (d.percent == null ? null : `${fmt.signedDelta(d.percent * 100, { digits: 0 })}%`);

  /** "előző hét 4" — the previous period's own figure, or why there is none. */
  const previousLine = (kpi: Kpi, show: (v: number) => string) =>
    kpi.previous == null ? t(period === "year" ? "noPreviousYear" : "noPrevious") : t("vsPrevious", { period, value: show(kpi.previous) });
  /** "előző hét" — for the percentage chips, which already carry the number. */
  const previousOnly = (kpi: Kpi) => (kpi.delta == null ? t(period === "year" ? "noPreviousYear" : "noPrevious") : t("vsPreviousShort", { period }));

  const calories = kpis.calories;
  const weight = kpis.weight;
  const weightWord = weight.delta?.tone === "good" ? t("improving") : weight.delta?.tone === "bad" ? t("worsening") : null;

  const tiles = [
    {
      id: "calories",
      icon: "local_fire_department",
      color: "var(--m-kcal)",
      label: t("avgCalories"),
      value: calories.value == null ? dash : fmt.integer(calories.value),
      unit: calories.value == null ? undefined : "kcal",
      delta: calories.delta && <ToneChip label={signed(calories.delta.amount)} tone={calories.delta.tone} />,
      subline:
        calories.value == null
          ? t("noLoggedDays")
          : calories.goal != null
            ? t("toGoal")
            : previousLine(calories, (v) => fmt.integer(v)),
    },
    {
      id: "weight",
      icon: "monitor_weight",
      color: "var(--m-weight)",
      label: t("weight"),
      value: weight.value == null ? dash : fmt.signedDelta(weight.value, { digits: 1 }),
      unit: weight.value == null ? undefined : "kg",
      delta: weightWord && weight.delta && <ToneChip label={weightWord} tone={weight.delta.tone} />,
      subline: weight.value == null ? t("needTwoWeighIns") : previousLine(weight, (v) => fmt.signedDelta(v, { digits: 1 })),
    },
    {
      id: "workouts",
      icon: "fitness_center",
      color: "var(--primary)",
      label: t("workouts"),
      value: fmt.integer(kpis.workouts.value ?? 0),
      delta: kpis.workouts.delta && <ToneChip label={signed(kpis.workouts.delta.amount)} tone={kpis.workouts.delta.tone} />,
      subline: previousLine(kpis.workouts, (v) => fmt.integer(v)),
    },
    {
      id: "volume",
      icon: "exercise",
      color: "var(--primary)",
      label: t("volume"),
      value: fmt.integer(kpis.volume.value ?? 0),
      unit: "kg",
      delta: kpis.volume.delta && percent(kpis.volume.delta) && <ToneChip label={percent(kpis.volume.delta)!} tone={kpis.volume.delta.tone} />,
      subline: previousOnly(kpis.volume),
    },
    {
      id: "cardio",
      icon: "directions_run",
      color: "var(--heart)",
      label: t("cardioDistance"),
      value: fmt.number(kpis.cardio.value ?? 0),
      unit: "km",
      delta: kpis.cardio.delta && <ToneChip label={signed(kpis.cardio.delta.amount, "km", Number.isInteger(Number(kpis.cardio.delta.amount.toFixed(1))) ? 0 : 1)} tone={kpis.cardio.delta.tone} />,
      subline: previousOnly(kpis.cardio),
    },
    {
      id: "steps",
      icon: "directions_walk",
      color: "var(--m-steps)",
      label: t("avgSteps"),
      value: kpis.steps.value == null ? dash : fmt.integer(kpis.steps.value),
      delta: kpis.steps.delta && percent(kpis.steps.delta) && <ToneChip label={percent(kpis.steps.delta)!} tone={kpis.steps.delta.tone} />,
      subline: kpis.steps.value == null ? t("noStepDays") : previousOnly(kpis.steps),
    },
  ];

  return (
    <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-2.5 md:gap-4" data-testid="stats-kpis">
      {tiles.map((tile, i) => (
        <MetricTile
          key={tile.id}
          compact
          valueSize={valueSize}
          icon={tile.icon}
          color={tile.color}
          label={tile.label}
          value={tile.value}
          unit={tile.unit}
          unitRatio={0.46}
          delta={tile.delta || undefined}
          subline={tile.subline}
          className={i >= 4 ? "max-md:hidden" : undefined}
        />
      ))}
    </div>
  );
}
