import type { AssignmentListItemResponse, ProgramAssignmentSummaryResponse } from "./types";

export type PlanKind = "PROGRAM" | "TEMPLATE" | "RECIPE";
export type PlanStatus = "ACTIVE" | "DONE" | "SCHEDULED";

export interface PlanItem {
  /** The id of the assignment row in its own table — together with `kind` it is the revoke target. */
  id: number;
  kind: PlanKind;
  sourceId: number | null;
  name: string;
  /** ISO date the item starts (a program) or was assigned (template, recipe). */
  from: string;
  /** ISO date a program ends; null for single items. */
  to: string | null;
  status: PlanStatus;
  /** Workouts of a program that were due and not done. */
  missed: number;
}

/** A program's status against `today` (ISO date): not started yet, running, or over / nothing left to do. */
export function programStatus(p: Pick<ProgramAssignmentSummaryResponse, "startDate" | "endDate" | "remainingCount">, today: string): PlanStatus {
  if (today < p.startDate) return "SCHEDULED";
  if (today > p.endDate || p.remainingCount === 0) return "DONE";
  return "ACTIVE";
}

/**
 * One client's assigned plans as a flat list for the grouped page (W9-C): the multi-week programs (cancelled ones
 * left out) and the single templates and recipes — a template or recipe is a copy in the client's account from the
 * day it was assigned, so it counts as active. Programs first, then the rest newest first.
 */
export function planItems(
  assignments: readonly AssignmentListItemResponse[],
  programs: readonly ProgramAssignmentSummaryResponse[],
  sourceName: (kind: "TEMPLATE" | "RECIPE", sourceId: number) => string,
  today: string,
): PlanItem[] {
  const programItems: PlanItem[] = programs
    .filter((p) => p.cancelledAt == null)
    .map((p) => ({
      id: p.id,
      kind: "PROGRAM" as const,
      sourceId: p.programId,
      name: p.programName,
      from: p.startDate,
      to: p.endDate,
      status: programStatus(p, today),
      missed: p.missedCount,
    }))
    .sort((a, b) => b.from.localeCompare(a.from));
  const singles: PlanItem[] = assignments
    .map((a) => ({
      id: a.id,
      kind: a.contentType,
      sourceId: a.sourceId,
      name: sourceName(a.contentType, a.sourceId),
      from: a.assignedAt.slice(0, 10),
      to: null,
      status: "ACTIVE" as const,
      missed: 0,
    }))
    .sort((a, b) => b.from.localeCompare(a.from));
  return [...programItems, ...singles];
}
