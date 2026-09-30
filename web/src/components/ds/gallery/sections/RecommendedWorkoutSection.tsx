"use client";

import { RecommendedWorkout } from "@/features/workouts/components/RecommendedWorkout";

const noop = () => {};

/** The dashboard's recommended-workout card (W1.4): a suggestion with history
 *  (rep counts known), one without (sets only), and the template-picker state. */
export function RecommendedWorkoutSection() {
  return (
    <div className="grid gap-6 md:grid-cols-3">
      <div data-state="with-history">
        <RecommendedWorkout
          name="Leg + core"
          summary={{
            exerciseCount: 6,
            totalSets: 18,
            estimatedMinutes: 50,
            lastPerformed: new Date(2026, 8, 23),
            preview: [
              { exerciseId: 1, name: "Back squat", sets: 4, reps: 8 },
              { exerciseId: 2, name: "Romanian deadlift", sets: 3, reps: 10 },
              { exerciseId: 3, name: "Walking lunge", sets: 3, reps: 12 },
            ],
          }}
          onStart={noop}
          onPickTemplate={noop}
        />
      </div>
      <div data-state="no-history">
        <RecommendedWorkout
          name="Push day"
          summary={{
            exerciseCount: 2,
            totalSets: 7,
            estimatedMinutes: 15,
            lastPerformed: null,
            preview: [
              { exerciseId: 1, name: "Bench press", sets: 4, reps: null },
              { exerciseId: 2, name: "Overhead press", sets: 3, reps: null },
            ],
          }}
          onStart={noop}
          onPickTemplate={noop}
        />
      </div>
      <div data-state="picker">
        <RecommendedWorkout name={null} summary={null} onStart={noop} onPickTemplate={noop} />
      </div>
    </div>
  );
}
