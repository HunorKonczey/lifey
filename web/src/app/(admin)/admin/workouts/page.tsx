"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { TemplatesView } from "@/features/workouts/components/TemplatesView";
import { ExercisesView } from "@/features/workouts/components/ExercisesView";
import { exerciseApi } from "@/features/workouts/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { AssignToClientDrawer, type AssignSummaryRow } from "@/features/trainer/components/AssignToClientDrawer";
import { ScheduleWorkoutDrawer } from "@/features/trainer/components/ScheduleWorkoutDrawer";
import type { WorkoutTemplateResponse } from "@/features/workouts/types";

type Tab = "templates" | "exercises";

export default function AdminWorkoutsPage() {
  const t = useTranslations("workouts");
  const [tab, setTab] = useState<Tab>("templates");
  const [assignTarget, setAssignTarget] = useState<WorkoutTemplateResponse | null>(null);
  const [scheduleTarget, setScheduleTarget] = useState<WorkoutTemplateResponse | null>(null);
  const { data: exercises } = useQuery({ queryKey: queryKeys.exercises.all(), queryFn: exerciseApi.list });

  const TABS: { value: Tab; label: string; icon: string }[] = [
    { value: "templates", label: t("templates"), icon: "list_alt" },
    { value: "exercises", label: t("exercises"), icon: "fitness_center" },
  ];

  const exerciseName = (id: number) => exercises?.find((e) => e.id === id)?.name ?? `#${id}`;
  const summary: AssignSummaryRow[] = (assignTarget?.exercises ?? []).slice(0, 4).map((e) => ({
    label: exerciseName(e.exerciseId),
    detail: t("setsSuffix", { count: e.targetSets }),
  }));
  const moreCount = Math.max(0, (assignTarget?.exercises.length ?? 0) - 4);

  return (
    <div className="flex flex-col gap-5">
      <SegmentedControl options={TABS} value={tab} onChange={setTab} activeBackground="var(--tertiary)" activeColor="#161611" />

      {tab === "templates" && <TemplatesView onAssign={setAssignTarget} onSchedule={setScheduleTarget} />}
      {tab === "exercises" && <ExercisesView />}

      {assignTarget && (
        <AssignToClientDrawer
          contentType="TEMPLATE"
          sourceId={assignTarget.id}
          title={assignTarget.name}
          summary={summary}
          moreCount={moreCount}
          onClose={() => setAssignTarget(null)}
        />
      )}

      {scheduleTarget && (
        <ScheduleWorkoutDrawer
          templateId={scheduleTarget.id}
          templateName={scheduleTarget.name}
          onClose={() => setScheduleTarget(null)}
        />
      )}
    </div>
  );
}
