import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "./types";

// Looks for a repeating cycle in the templates used across sessionsDesc
// (newest first) and predicts the id of the template that continues it.
//
// Unfinished sessions (started but not yet completed) are excluded, and so
// is every session with no templateId — every cardio session (docs/cardio/51
// §1.1: no cardio templates in V1, so `templateId` is always null) among
// others. That null-templateId filter runs *before* taking the most recent
// 10, not after: a cardio session interleaved with a strength cycle still
// has `finishedAt` set, so slicing to 10 first (then filtering nulls) would
// let cardio noise crowd real signal out of the window — the same ordering
// bug the mobile `recommended_template_provider.dart` fixed for the same
// reason. Only the most recent 10 *template-having* finished sessions are
// considered, so a routine change a few weeks ago doesn't keep influencing
// today's suggestion. Returns null when there's too little history or no
// exact repeating pattern — no recommendation is better than a wrong one.
export function predictNextTemplateId(sessionsDesc: WorkoutSessionResponse[]): number | null {
  const seq = sessionsDesc
    .filter((s) => s.finishedAt != null)
    .map((s) => s.templateId)
    .filter((id): id is number => id != null)
    .slice(0, 10)
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
