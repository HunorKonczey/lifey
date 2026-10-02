"use client";

import { Card } from "../../Card";
import { LifeyLineChart, type LineChartPoint } from "../../charts/LifeyLineChart.lazy";

// DS-04's weight sample: aug. 18. – szept. 27., with gaps (skipped weigh-ins).
function buildData(): LineChartPoint[] {
  const start = new Date(2026, 7, 18); // Aug 18
  const raw: Record<number, number> = {
    0: 72, 2: 71.6, 3: 71.4, 6: 71.2, 7: 71, 10: 70.5, 11: 70.3,
    14: 70, 17: 69.6, 18: 69.4, 21: 69, 24: 68.6, 25: 68.5,
    28: 68, 31: 67.6, 34: 67.2, 35: 67, 38: 66.6, 39: 66.4, 40: 66.6,
  };
  const days = 40; // through Sep 27
  return Array.from({ length: days + 1 }, (_, i) => ({
    date: new Date(start.getFullYear(), start.getMonth(), start.getDate() + i),
    value: raw[i] ?? null,
  }));
}

const DATA = buildData();

/** D-W0.19/D-W0.9 — the DS-04 weight sample: gaps left as gaps
 *  (`connectNulls={false}`), a 7-day moving average, a goal line, and the
 *  last point emphasised with a card-colour ring. */
export function LineChartSection() {
  return (
    <Card>
      <LifeyLineChart
        aria-label="Weight, August 18 to September 27"
        data={DATA}
        color="var(--m-weight)"
        goal={65}
        goalLabel="cél 65 kg"
        unit=" kg"
        showAverage
        legend={{ raw: "napi mérés", average: "7 napos átlag", goal: "cél" }}
      />
    </Card>
  );
}
