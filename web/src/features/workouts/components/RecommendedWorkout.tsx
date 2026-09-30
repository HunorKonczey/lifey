"use client";

import { useTranslations } from "next-intl";
import { Button, Card, Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import type { RecommendedSummary } from "../recommendedSummary";

export interface RecommendedWorkoutProps {
  /** The suggested template's name, or null when there is no suggestion. */
  name: string | null;
  summary: RecommendedSummary | null;
  onStart: () => void;
  /** With no suggestion the card becomes the entry to the template list. */
  onPickTemplate: () => void;
  starting?: boolean;
}

/**
 * The dashboard's "today's suggestion" (W1.4, client-001): the template's
 * name at 20/800, one meta line (exercises · about N min · N sets), the first
 * three exercises with "4 × 8", and a full-width primary start button. With
 * no suggestion the card stays in the grid as a template picker instead of
 * disappearing — the row beside the hero never has a hole in it.
 */
export function RecommendedWorkout({ name, summary, onStart, onPickTemplate, starting }: RecommendedWorkoutProps) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();

  if (!name || !summary) {
    return (
      <Card variant="hero" className="flex h-full flex-col justify-between gap-4" style={{ padding: 24 }} data-testid="recommended-workout">
        <div>
          <span className="type-section" style={{ color: "var(--text-3)" }}>
            {t("todaySuggestion")}
          </span>
          <h3 className="mt-2" style={{ fontSize: 20, fontWeight: 800, letterSpacing: "-0.02em" }}>
            {t("pickTemplateTitle")}
          </h3>
          <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }}>
            {t("pickTemplateBody")}
          </p>
        </div>
        <Button variant="secondary" fullWidth onClick={onPickTemplate}>
          <Icon name="list_alt" size={20} />
          {t("openTemplates")}
        </Button>
      </Card>
    );
  }

  return (
    <Card variant="hero" className="flex h-full flex-col gap-4" style={{ padding: 24 }} data-testid="recommended-workout">
      <div className="flex items-baseline justify-between gap-3">
        <span className="type-section" style={{ color: "var(--text-3)" }}>
          {t("todaySuggestion")}
        </span>
        {summary.lastPerformed && (
          <span className="type-body-s shrink-0" style={{ color: "var(--text-3)" }}>
            {t("lastPerformed", { date: fmt.shortDate(summary.lastPerformed) })}
          </span>
        )}
      </div>

      <div>
        <h3 style={{ fontSize: 20, fontWeight: 800, letterSpacing: "-0.02em" }}>{name}</h3>
        <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }}>
          {t("workoutMeta", { exercises: summary.exerciseCount, minutes: summary.estimatedMinutes, sets: summary.totalSets })}
        </p>
      </div>

      <ul className="flex flex-col gap-2.5">
        {summary.preview.map((e) => (
          <li key={e.exerciseId} className="flex items-baseline justify-between gap-3">
            <span className="truncate" style={{ fontSize: 14, fontWeight: 600 }}>
              {e.name}
            </span>
            <span className="tabular shrink-0" style={{ fontSize: 14, fontWeight: 700, color: "var(--text-2)" }}>
              {e.reps != null ? t("setsTimesReps", { sets: e.sets, reps: e.reps }) : t("setsOnly", { sets: e.sets })}
            </span>
          </li>
        ))}
      </ul>

      <div className="mt-auto pt-1">
        <Button fullWidth onClick={onStart} disabled={starting}>
          <Icon name="play_arrow" size={20} fill={1} />
          {t("startWorkoutCta")}
        </Button>
      </div>
    </Card>
  );
}
