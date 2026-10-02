"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/status/Skeleton";

/**
 * Lazy-loaded wrapper around `LifeyLineChart` (D-W0.9) — same reasoning as
 * `LifeyBarChart.lazy.tsx`: the Recharts bundle is fetched only when a chart
 * actually renders, never from the root layout or marketing.
 */
export const LifeyLineChart = dynamic(() => import("./LifeyLineChart").then((m) => m.LifeyLineChart), {
  ssr: false,
  loading: () => <Skeleton variant="chart" />,
});

export type { LineChartPoint, LifeyLineChartProps } from "./LifeyLineChart";
