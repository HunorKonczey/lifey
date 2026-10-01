"use client";

import { DaySummaryView } from "@/features/nutrition/components/DaySummary";

/** The meals tab's day summary (W2.2): the canvas' 1 041 / 1 900 day, an over-budget day and a day with no goals. */
export function DaySummarySection() {
  return (
    <div className="grid gap-6 md:grid-cols-3">
      <div data-state="remaining">
        <DaySummaryView
          kcal={1041}
          goalKcal={1900}
          macros={{ protein: { value: 68, goal: 120 }, carbs: { value: 112, goal: 210 }, fat: { value: 34, goal: 63 } }}
        />
      </div>
      <div data-state="over">
        <DaySummaryView
          kcal={2112}
          goalKcal={1900}
          macros={{ protein: { value: 135, goal: 120 }, carbs: { value: 240, goal: 210 }, fat: { value: 70, goal: 63 } }}
        />
      </div>
      <div data-state="no-goal">
        <DaySummaryView
          kcal={640}
          goalKcal={null}
          macros={{ protein: { value: 41, goal: null }, carbs: { value: 80, goal: null }, fat: { value: 22, goal: null } }}
        />
      </div>
    </div>
  );
}
