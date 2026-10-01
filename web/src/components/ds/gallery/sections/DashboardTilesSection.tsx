"use client";

import { StepsTileView } from "@/features/dashboard/components/StepsTile";
import { WeightTileView } from "@/features/dashboard/components/WeightTile";

const noop = () => {};
const DAY = 86_400_000;

/** The dashboard's steps and weight tiles (W1.7) on fixture data: steps under
 *  and over the goal; weight with a goal and a losing pace, with a gaining pace
 *  and no goal, having reached the goal, and with no weigh-in yet. */
export function DashboardTilesSection() {
  const today = new Date();
  const daysAgo = (n: number) => new Date(today.getTime() - n * DAY);

  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      <div data-state="steps-under">
        <StepsTileView steps={6412} goal={9000} onClick={noop} />
      </div>
      <div data-state="steps-reached">
        <StepsTileView steps={9500} goal={9000} onClick={noop} />
      </div>
      <div data-state="weight-losing">
        <WeightTileView latest={{ weight: 69.6, date: today }} pace={-0.4} goalKg={65} trend={[70.4, 70.2, 70.3, 70.0, 69.9, 69.8, 69.6]} onClick={noop} />
      </div>
      <div data-state="weight-gaining-no-goal">
        <WeightTileView latest={{ weight: 61.2, date: daysAgo(1) }} pace={0.3} goalKg={null} onClick={noop} />
      </div>
      <div data-state="weight-reached">
        <WeightTileView latest={{ weight: 65.1, date: daysAgo(5) }} pace={null} goalKg={65} onClick={noop} />
      </div>
      <div data-state="weight-empty">
        <WeightTileView latest={null} pace={null} goalKg={null} onLog={noop} />
      </div>
    </div>
  );
}
