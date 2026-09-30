"use client";

import { WeekCaloriesCardView } from "@/features/dashboard/components/WeekCaloriesCard";
import { weekStats, type WeekDay } from "@/features/dashboard/weekCalories";

// A fixed week (24–30 Sep 2026, "today" = the 30th) so the numbers are
// stable: 4 of the 6 complete days within a 1 900 goal, one over, one unlogged.
const NOW = new Date(2026, 8, 30, 9, 30);
const KCAL = [1600, 2100, 1800, 0, 1700, 1900, 400];
const DAYS: WeekDay[] = KCAL.map((kcal, i) => ({ date: new Date(2026, 8, 24 + i), kcal, isToday: i === 6 }));
const SESSIONS = [new Date(2026, 8, 24, 7, 0).toISOString(), new Date(2026, 8, 26, 17, 30).toISOString()];

/** The dashboard's 7-day calories card (W1.8), with and without a goal. */
export function WeekCaloriesSection() {
  return (
    <div className="flex flex-col gap-6">
      <div data-state="goal">
        <WeekCaloriesCardView days={DAYS} goalKcal={1900} stats={weekStats(DAYS, 1900, SESSIONS, NOW)} />
      </div>
      <div data-state="no-goal">
        <WeekCaloriesCardView days={DAYS} goalKcal={null} stats={weekStats(DAYS, null, SESSIONS, NOW)} />
      </div>
    </div>
  );
}
