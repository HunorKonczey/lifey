"use client";

import { useTranslations } from "next-intl";
import type { WorkoutTemplateResponse } from "../types";

// Tinted, bordered card suggesting the next workout based on the user's
// repeating template rotation — visually distinct from the plain surface
// rows/cards around it so it doesn't read as "just another item" in the
// list. Clicking it starts a session from `template`.
export function RecommendedWorkoutCard({
  template,
  onStart,
  starting,
}: {
  template: WorkoutTemplateResponse;
  onStart: () => void;
  starting?: boolean;
}) {
  const t = useTranslations("workouts");

  return (
    <button
      onClick={onStart}
      disabled={starting}
      className="w-full flex items-center gap-3 px-4 py-3 rounded-[var(--r-card)] text-left disabled:opacity-60"
      style={{
        background: "color-mix(in srgb, var(--primary) 12%, var(--surface))",
        border: "1px solid color-mix(in srgb, var(--primary) 45%, transparent)",
      }}
    >
      <div
        className="flex items-center justify-center w-11 h-11 rounded-[var(--r-input)] shrink-0"
        style={{ background: "color-mix(in srgb, var(--primary) 18%, transparent)" }}
      >
        <span className="material-symbols-rounded text-2xl" style={{ color: "var(--primary)" }}>
          bolt
        </span>
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-xs font-bold uppercase tracking-wide" style={{ color: "var(--primary)" }}>
          {t("recommendedWorkout")}
        </p>
        <p className="text-base font-extrabold truncate">{template.name}</p>
      </div>
      <span className="material-symbols-rounded text-3xl shrink-0" style={{ color: "var(--primary)" }}>
        {starting ? "hourglass_empty" : "play_circle"}
      </span>
    </button>
  );
}
