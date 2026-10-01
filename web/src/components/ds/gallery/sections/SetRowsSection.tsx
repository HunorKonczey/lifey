"use client";

import { useState } from "react";
import { ExerciseCard } from "@/features/workouts/components/live/ExerciseCard";
import { baselineFromSets } from "@/features/workouts/personalRecords";
import { rowMarks, type DraftSet } from "@/features/workouts/liveSession";

const PREVIOUS = [
  { weight: 55, reps: 8 },
  { weight: 57.5, reps: 8 },
  { weight: 57.5, reps: 8 },
  { weight: 60, reps: 6 },
];
const HISTORY = PREVIOUS;

/** The live logger's set rows (W3.7, W3-B) on a small state machine — `e2e/ds/setRows.spec.ts` drives the keyboard path on it. */
export function SetRowsSection() {
  const [rows, setRows] = useState<DraftSet[]>([
    { exerciseId: 1, weight: 55, reps: 8, done: true },
    { exerciseId: 1, weight: 57.5, reps: 8, done: false },
    { exerciseId: 1, weight: 57.5, reps: 8, done: false },
  ]);

  return (
    <div className="max-w-3xl" data-testid="set-rows-demo">
      <ExerciseCard
        name="Guggolás"
        rows={rows.map((draft, index) => ({ draft, index }))}
        previous={PREVIOUS}
        marks={rowMarks(baselineFromSets(HISTORY), rows, PREVIOUS)}
        planned={4}
        best={{ weight: 60, reps: 6 }}
        onUpdate={(index, patch) => setRows((prev) => prev.map((r, i) => (i === index ? { ...r, ...patch } : r)))}
        onRemove={(index) => setRows((prev) => prev.filter((_, i) => i !== index))}
        onAddSet={() => setRows((prev) => [...prev, { ...prev[prev.length - 1], done: false }])}
      />
      <p className="type-body-s mt-2" data-testid="set-rows-state" style={{ color: "var(--text-3)" }}>
        {rows.map((r) => `${r.weight}×${r.reps}${r.done ? "✓" : ""}`).join(" ")}
      </p>
    </div>
  );
}
