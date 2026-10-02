import { clientDisplayName } from "./components/ClientAvatar";
import type { ExerciseResponse, WorkoutTemplateResponse } from "@/features/workouts/types";
import type { TrainerClientResponse } from "./types";

export interface TemplateUser {
  clientId: number;
  name: string;
  email: string;
}

/** The trainer's clients that have the template assigned, in the order of the client list; unknown ids are dropped. */
export function templateUsers(assignedClientIds: readonly number[] | undefined, clients: readonly TrainerClientResponse[]): TemplateUser[] {
  if (!assignedClientIds || assignedClientIds.length === 0) return [];
  const ids = new Set(assignedClientIds);
  return clients.filter((c) => ids.has(c.clientId)).map((c) => ({ clientId: c.clientId, name: clientDisplayName(c), email: c.clientEmail }));
}

/**
 * The template's muscle groups for its tag line ("Mell · Hát"): the distinct categories of its exercises in
 * order of first appearance, cardio / other / full body left out unless nothing else is there, at most `limit`.
 * Empty when no exercise has a category.
 */
export function templateTags(template: Pick<WorkoutTemplateResponse, "exercises">, exercises: readonly ExerciseResponse[], limit = 2): string[] {
  const byId = new Map(exercises.map((e) => [e.id, e.category]));
  const seen: string[] = [];
  for (const entry of template.exercises) {
    const category = byId.get(entry.exerciseId);
    if (category && !seen.includes(category)) seen.push(category);
  }
  const specific = seen.filter((c) => c !== "OTHER" && c !== "CARDIO" && c !== "FULL_BODY");
  return (specific.length > 0 ? specific : seen).slice(0, limit);
}

/** "6 exercises · 18 sets · about 50 min" as numbers — 8 minutes an exercise, rounded to 5 (the picker's estimate). */
export function templateTotals(entries: readonly { targetSets: number }[]): { exercises: number; sets: number; minutes: number } {
  return {
    exercises: entries.length,
    sets: entries.reduce((sum, e) => sum + e.targetSets, 0),
    minutes: Math.round((entries.length * 8) / 5) * 5,
  };
}
