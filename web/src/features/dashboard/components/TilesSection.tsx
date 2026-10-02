"use client";

import { Skeleton } from "@/components/status/Skeleton";
import type { DashboardData } from "../useDashboardData";
import { StepsTile } from "./StepsTile";
import { WaterTile } from "./WaterTile";
import { WeightTile } from "./WeightTile";

/** The Water / Steps / Weight row (W1.5, W1.7): three equal tiles from 768 up;
 *  on a phone water and steps sit 2-up and weight takes the full width below
 *  (W1-C). The gap is the page grid's, so the row lines up with the cards above. */
export function TilesSection({ data }: { data: DashboardData }) {
  const { queries } = data;
  const card = <Skeleton variant="card" className="h-40" />;

  return (
    <div className="grid grid-cols-2 md:grid-cols-3" style={{ gap: "var(--grid-gap)" }}>
      {queries.waterEntriesQ.isLoading ? card : <WaterTile data={data} />}
      {queries.stepsQ.isLoading ? card : <StepsTile data={data} />}
      <div className="col-span-2 md:col-span-1 *:h-full">{queries.weightsQ.isLoading ? card : <WeightTile data={data} />}</div>
    </div>
  );
}
