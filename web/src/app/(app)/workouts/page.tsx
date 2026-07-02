"use client";

import { useTranslations } from "next-intl";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { SessionsView } from "@/features/workouts/components/SessionsView";
import { TemplatesView } from "@/features/workouts/components/TemplatesView";
import { ExercisesView } from "@/features/workouts/components/ExercisesView";
import { useUiStore } from "@/lib/hooks/useUiStore";

type Tab = "sessions" | "templates" | "exercises";

export default function WorkoutsPage() {
  const t = useTranslations("workouts");
  const tab = useUiStore((s) => s.workoutsTab);
  const setTab = useUiStore((s) => s.setWorkoutsTab);

  const TABS: { value: Tab; label: string; icon: string }[] = [
    { value: "sessions", label: t("sessions"), icon: "exercise" },
    { value: "templates", label: t("templates"), icon: "list_alt" },
    { value: "exercises", label: t("exercises"), icon: "fitness_center" },
  ];

  return (
    <div className="flex flex-col gap-5">
      <SegmentedControl options={TABS} value={tab} onChange={setTab} />

      {tab === "sessions" && <SessionsView />}
      {tab === "templates" && <TemplatesView />}
      {tab === "exercises" && <ExercisesView />}
    </div>
  );
}
