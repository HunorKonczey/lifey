"use client";

import { useRouter } from "next/navigation";
import { RecommendedWorkoutCard } from "@/features/workouts/components/RecommendedWorkoutCard";
import type { DashboardData } from "../useDashboardData";

/** W1.1 shell for the recommended-workout slot (old banner card, unchanged);
 *  rewritten as `RecommendedWorkout` in W1.4. */
export function RecommendedSection({ data }: { data: DashboardData }) {
  const router = useRouter();
  const { recommended } = data;
  if (!recommended) return null;
  return <RecommendedWorkoutCard template={recommended} onStart={() => router.push(`/workouts?start=${recommended.id}`)} />;
}
