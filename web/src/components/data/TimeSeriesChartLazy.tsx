"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/status/Skeleton";

/**
 * Lazy-loaded wrapper around TimeSeriesChart so the heavy Recharts bundle
 * is fetched only when a chart actually renders, after the route shell paints.
 */
export const TimeSeriesChart = dynamic(
  () => import("./TimeSeriesChart").then((m) => m.TimeSeriesChart),
  {
    ssr: false,
    loading: () => <Skeleton variant="chart" />,
  },
);

export type { SeriesPoint } from "./TimeSeriesChart";
