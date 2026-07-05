import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "./types";

// Looks for a repeating cycle in the templates used across sessionsDesc
// (newest first) and predicts the id of the template that continues it.
//
// Only the most recent 10 sessions are considered, so a routine change a
// few weeks ago doesn't keep influencing today's suggestion. Returns null
// when there's too little history or no exact repeating pattern — no
// recommendation is better than a wrong one.
export function predictNextTemplateId(sessionsDesc: WorkoutSessionResponse[]): number | null {
  const seq = sessionsDesc
    .slice(0, 10)
    .map((s) => s.templateId)
    .filter((id): id is number => id != null)
    .reverse();
  if (seq.length < 2) return null;

  for (let period = 1; period <= Math.floor(seq.length / 2); period++) {
    let matches = true;
    for (let i = period; i < seq.length; i++) {
      if (seq[i] !== seq[i - period]) {
        matches = false;
        break;
      }
    }
    if (matches) return seq[seq.length - period];
  }
  return null;
}

export function recommendedTemplate(
  sessionsDesc: WorkoutSessionResponse[],
  templates: WorkoutTemplateResponse[],
): WorkoutTemplateResponse | null {
  const id = predictNextTemplateId(sessionsDesc);
  if (id == null) return null;
  return templates.find((t) => t.id === id) ?? null;
}
