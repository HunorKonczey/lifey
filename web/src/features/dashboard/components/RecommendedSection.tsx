"use client";

import { useRouter } from "next/navigation";
import { RecommendedWorkout } from "@/features/workouts/components/RecommendedWorkout";
import { useUiStore } from "@/lib/hooks/useUiStore";
import type { DashboardData } from "../useDashboardData";

/** The recommended-workout slot (W1.4): the suggestion card, or — with no
 *  suggestion — the template picker, so the grid cell never collapses.
 *  Starting hands the template to the workouts page, which starts the session
 *  exactly as before (`?start=<templateId>`). */
export function RecommendedSection({ data }: { data: DashboardData }) {
  const router = useRouter();
  const { recommended, recommendedSummary } = data;

  return (
    <RecommendedWorkout
      name={recommended?.name ?? null}
      summary={recommendedSummary}
      onStart={() => recommended && router.push(`/workouts?start=${recommended.id}`)}
      onPickTemplate={() => {
        useUiStore.getState().setWorkoutsTab("templates");
        router.push("/workouts");
      }}
    />
  );
}
