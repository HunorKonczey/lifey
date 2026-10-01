"use client";

import { RecentWorkoutsView, type RecentWorkoutRow } from "@/features/dashboard/components/RecentWorkouts";

const noop = () => {};

const ROWS: RecentWorkoutRow[] = [
  { id: 1, kind: "strength", name: "Leg + core", meta: "52 min · 6,240 kg · 18 sets", dateLabel: "yesterday", icon: "fitness_center", isPr: true },
  { id: 2, kind: "cardio", name: "Running", meta: "5.2 km · 30:10 · 5:48 /km", dateLabel: "Sep 25", icon: "directions_run", isPr: false },
  { id: 3, kind: "strength", name: "Pull day", meta: "44 min · 4,880 kg · 14 sets", dateLabel: "Sep 23", icon: "fitness_center", isPr: false },
  { id: 4, kind: "cardio", name: "Cycling", meta: "18.4 km · 52:00", dateLabel: "Sep 21", icon: "directions_bike", isPr: false },
];

/** The dashboard's recent-workouts card (W1.10): a full list with a PR on one
 *  row, and an empty account. */
export function RecentWorkoutsSection() {
  return (
    <div className="grid gap-6 md:grid-cols-2">
      <div data-state="rows">
        <RecentWorkoutsView rows={ROWS} onOpen={noop} />
      </div>
      <div data-state="empty">
        <RecentWorkoutsView rows={[]} onStart={noop} />
      </div>
    </div>
  );
}
