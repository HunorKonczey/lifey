"use client";

import { TemplateEditorPanel } from "@/features/workouts/components/TemplateEditorPanel";
import type { ExerciseResponse, WorkoutTemplateResponse } from "@/features/workouts/types";

const EXERCISES: ExerciseResponse[] = ["Guggolás", "Román felhúzás", "Kitörés", "Vádliemelés", "Plank"].map((name, i) => ({
  id: i + 1,
  name,
  category: null,
  equipment: null,
  description: null,
}));

const TEMPLATE: WorkoutTemplateResponse = {
  id: 1,
  name: "Láb + core",
  exercises: [
    { exerciseId: 1, targetSets: 4 },
    { exerciseId: 2, targetSets: 3 },
    { exerciseId: 3, targetSets: 3 },
  ],
};

/** The Templates tab's editor (W3.11) on static data — `e2e/ds/templateEditor.spec.ts` drives the reorder and the set stepper on it. */
export function TemplateEditorSection() {
  return (
    <div className="max-w-md" data-testid="template-editor-demo">
      <TemplateEditorPanel template={TEMPLATE} exercises={EXERCISES} bare onSaved={() => {}} onDeleted={() => {}} />
    </div>
  );
}
