"use client";

import { useState } from "react";
import { Card } from "../../Card";
import { MetricValue } from "../../MetricValue";
import { DeltaChip } from "../../DeltaChip";
import { MetricBar } from "../../progress/MetricBar";
import { MetricTile } from "../../progress/MetricTile";
import { ProgressRing } from "../../progress/ProgressRing";
import { RatioBar } from "../../progress/RatioBar";
import { SegmentBar } from "../../progress/SegmentBar";

const STATES = [
  { label: "0%", value: 0 },
  { label: "22%", value: 0.22 },
  { label: "100%", value: 1 },
  { label: "130%", value: 1.3 },
];

/** W1.5: a SegmentBar that can be nudged, to show only the delta animating. */
function AddableSegmentBar() {
  const [progress, setProgress] = useState(0.4);
  return (
    <Card className="flex flex-col gap-3 max-w-sm">
      <span className="type-body-s" style={{ color: "var(--text-3)" }}>
        SegmentBar, add 0.25 L (only the difference animates)
      </span>
      <div data-testid="segment-demo">
        <SegmentBar progress={progress} color="var(--m-water)" height={8} />
      </div>
      <button
        type="button"
        data-testid="segment-demo-add"
        className="lifey-button self-start px-4 h-10 type-button"
        style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}
        onClick={() => setProgress((p) => Math.min(1, p + 0.25))}
      >
        + 0.25 L
      </button>
    </Card>
  );
}

/** D-W0.16 — ProgressRing/MetricBar/RatioBar/SegmentBar/MetricTile at the
 *  0 / 22 / 100 / 130% states the plan calls for; `ringSweeps` itself is
 *  unit-tested (`ringSweeps.test.ts`), never a ring past 360°. */
export function ProgressSection() {
  return (
    <div className="flex flex-col gap-6">
      <Card className="flex flex-wrap items-center gap-8">
        {STATES.map((s) => (
          <div key={s.label} className="flex flex-col items-center gap-2">
            <ProgressRing progress={s.value} color="var(--m-kcal)" size={88} aria-label={`Calories, ${s.label} of goal`}>
              <MetricValue value={s.label} size={20} />
            </ProgressRing>
            <span className="type-body-s" style={{ color: "var(--text-3)" }}>
              {s.label}
            </span>
          </div>
        ))}
      </Card>

      <Card className="flex flex-col gap-4 max-w-sm">
        {STATES.map((s) => (
          <div key={s.label} className="flex flex-col gap-1.5">
            <span className="type-body-s" style={{ color: "var(--text-3)" }}>
              MetricBar {s.label}
            </span>
            <MetricBar progress={s.value} color="var(--m-protein)" />
          </div>
        ))}
      </Card>

      <Card className="flex flex-col gap-4 max-w-sm">
        <span className="type-body-s" style={{ color: "var(--text-3)" }}>
          RatioBar — protein/carbs/fat kcal against an 1800 kcal goal
        </span>
        <RatioBar
          total={1800}
          segments={[
            { value: 320, color: "var(--m-protein)" },
            { value: 540, color: "var(--m-carbs)" },
            { value: 260, color: "var(--m-fat)" },
          ]}
        />
        <span className="type-body-s" style={{ color: "var(--text-3)" }}>
          RatioBar — no total, 100% split
        </span>
        <RatioBar
          segments={[
            { value: 32, color: "var(--m-protein)" },
            { value: 54, color: "var(--m-carbs)" },
            { value: 26, color: "var(--m-fat)" },
          ]}
        />
      </Card>

      <Card className="flex flex-col gap-4 max-w-sm">
        {STATES.map((s) => (
          <div key={s.label} className="flex flex-col gap-1.5">
            <span className="type-body-s" style={{ color: "var(--text-3)" }}>
              SegmentBar {s.label}
            </span>
            <SegmentBar progress={s.value} color="var(--m-water)" />
          </div>
        ))}
      </Card>

      <AddableSegmentBar />

      <div className="flex flex-wrap gap-4">
        <MetricTile
          icon="local_fire_department"
          label="Calories"
          meta="last at 14:10"
          value={1840}
          unit="/ 2200 kcal"
          color="var(--m-kcal)"
          progress={1840 / 2200}
          delta={<DeltaChip value={-120} goalDirection="lower" />}
          subline="212 kcal left today"
          className="w-64"
        />
        <MetricTile
          icon="water_drop"
          label="Water"
          value={1.6}
          unit="/ 2.5 L"
          color="var(--m-water)"
          segments={{ progress: 1.6 / 2.5 }}
          className="w-64"
        />
      </div>
    </div>
  );
}
