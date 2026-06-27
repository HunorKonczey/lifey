"use client";

import { useState } from "react";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { SessionsView } from "@/features/workouts/components/SessionsView";
import { TemplatesView } from "@/features/workouts/components/TemplatesView";
import { ExercisesView } from "@/features/workouts/components/ExercisesView";

type Tab = "sessions" | "templates" | "exercises";

const TABS: { value: Tab; label: string; icon: string }[] = [
  { value: "sessions", label: "Sessions", icon: "exercise" },
  { value: "templates", label: "Templates", icon: "list_alt" },
  { value: "exercises", label: "Exercises", icon: "fitness_center" },
];

export default function WorkoutsPage() {
  const [tab, setTab] = useState<Tab>("sessions");

  return (
    <div className="flex flex-col gap-5">
      <SegmentedControl options={TABS} value={tab} onChange={setTab} />

      {tab === "sessions" && <SessionsView />}
      {tab === "templates" && <TemplatesView />}
      {tab === "exercises" && <ExercisesView />}
    </div>
  );
}
