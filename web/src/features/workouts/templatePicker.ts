import { summarizeTemplate } from "./recommendedSummary";
import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "./types";

export interface PickerTemplate {
  template: WorkoutTemplateResponse;
  exerciseCount: number;
  /** The template's median past duration, else 8 minutes an exercise — rounded to 5. */
  estimatedMinutes: number;
  /** Whole local days since the template was last finished; null if never. 0 = today. */
  daysAgo: number | null;
  recommended: boolean;
}

/** Whole calendar days from `from` to `now` in local time (DST-proof: midnights are compared, not 24 h spans). */
export function daysBetween(from: Date, now: Date): number {
  return Math.round(
    (Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()) - Date.UTC(from.getFullYear(), from.getMonth(), from.getDate())) / 86_400_000,
  );
}

/**
 * The tiles of the start-workout picker (W3.5, W3-F): every template with its exercise count, estimated time
 * and "last used" day count, the recommended one first (the rest keep their order). `sessionsDesc` is newest first.
 */
export function pickerTemplates(
  templates: readonly WorkoutTemplateResponse[],
  sessionsDesc: WorkoutSessionResponse[],
  recommendedId: number | null,
  now: Date,
): PickerTemplate[] {
  const items = templates.map((template) => {
    const summary = summarizeTemplate(template, sessionsDesc, new Map());
    return {
      template,
      exerciseCount: summary.exerciseCount,
      estimatedMinutes: summary.estimatedMinutes,
      daysAgo: summary.lastPerformed ? Math.max(0, daysBetween(summary.lastPerformed, now)) : null,
      recommended: template.id === recommendedId,
    };
  });
  return [...items.filter((i) => i.recommended), ...items.filter((i) => !i.recommended)];
}
