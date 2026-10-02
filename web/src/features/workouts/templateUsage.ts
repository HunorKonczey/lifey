import { weekStartFor } from "./sessionGroups";
import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "./types";

export interface TemplateUsage {
  templateId: number;
  name: string;
  /** Workouts started from the template in each of the last weeks, oldest first — `weeks` entries, the last one the current week. */
  perWeek: number[];
  total: number;
}

/**
 * How often each template was used over the last `weeks` calendar weeks (Monday-based, the current week
 * included) — the panel of the Templates tab when nothing is selected (W3.11, W3-F). Every template is listed,
 * unused ones with zeros; most used first, ties in the templates' own order. A session counts when it started in
 * the window, finished or not; sessions without a template (empty workouts, cardio) are not anyone's usage.
 */
export function templateUsage(
  templates: readonly WorkoutTemplateResponse[],
  sessions: readonly WorkoutSessionResponse[],
  now: Date,
  weeks = 4,
): TemplateUsage[] {
  const currentWeek = weekStartFor(now);
  const starts = Array.from({ length: weeks }, (_, i) => new Date(currentWeek.getFullYear(), currentWeek.getMonth(), currentWeek.getDate() - 7 * (weeks - 1 - i)).getTime());

  const usage = templates.map((template) => ({ templateId: template.id, name: template.name, perWeek: Array<number>(weeks).fill(0), total: 0 }));
  const byId = new Map(usage.map((u) => [u.templateId, u]));

  for (const session of sessions) {
    if (session.templateId == null) continue;
    const entry = byId.get(session.templateId);
    if (!entry) continue;
    const weekStart = weekStartFor(new Date(session.startedAt)).getTime();
    const index = starts.indexOf(weekStart);
    if (index < 0) continue; // older than the window (or in the future)
    entry.perWeek[index] += 1;
    entry.total += 1;
  }

  return usage.map((u, i) => ({ u, i })).sort((a, b) => b.u.total - a.u.total || a.i - b.i).map(({ u }) => u);
}
