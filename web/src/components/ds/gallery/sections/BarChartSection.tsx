"use client";

import { Card } from "../../Card";
import { LifeyBarChart, type BarChartDatum } from "../../charts/LifeyBarChart.lazy";
import { averageExcludingPartialToday } from "../../charts/chartMath";

// DS-04's calories sample: V H K Sze Cs P Ma (Hungarian weekday initials —
// kept literal here so the gallery matches the plan's own spec regardless
// of the toolbar's EN/HU toggle, which only affects axis-number formatting).
const LABELS = ["V", "H", "K", "Sze", "Cs", "P", "Ma"];
const VALUES = [1720, 1980, 1650, 2050, 1690, 1780, 300];
const NOW = new Date(2026, 8, 24, 8, 30);

const DATA: BarChartDatum[] = LABELS.map((label, i) => ({
  label,
  value: VALUES[i],
  isToday: i === LABELS.length - 1,
}));

const average = averageExcludingPartialToday(
  DATA.map((d, i) => ({ day: new Date(2026, 8, 18 + i), value: d.value })),
  NOW,
);

/** D-W0.18/D-W0.9 — the DS-04 calories bar-chart sample: today dashed and
 *  unfilled, a goal reference line, and the average excluding today's
 *  partial day (`chartMath.averageExcludingPartialToday`). */
export function BarChartSection() {
  return (
    <Card>
      <LifeyBarChart
        aria-label="Calories this week"
        data={DATA}
        color="var(--m-kcal)"
        goal={1900}
        goalLabel="cél 1900"
        legend={`Average ${Math.round(average ?? 0).toLocaleString()} kcal without today`}
      />
    </Card>
  );
}
