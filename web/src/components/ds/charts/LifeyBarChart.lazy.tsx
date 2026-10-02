"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/status/Skeleton";

/**
 * Lazy-loaded wrapper around `LifeyBarChart` (D-W0.9) so the Recharts bundle
 * is fetched only when a chart actually renders, from an app page — never
 * imported by the root layout or marketing (the JS-budget script caught a
 * 95KB Recharts leak there once).
 */
export const LifeyBarChart = dynamic(() => import("./LifeyBarChart").then((m) => m.LifeyBarChart), {
  ssr: false,
  loading: () => <Skeleton variant="chart" />,
});

export type { BarChartDatum, LifeyBarChartProps } from "./LifeyBarChart";
