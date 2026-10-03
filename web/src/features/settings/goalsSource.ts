/** Who last changed a user's nutrition goals (docs/redesign-web/82 section 2.4). UNKNOWN = never recorded: no chip, no date. */
export type GoalsSource = "UNKNOWN" | "SELF" | "TRAINER";

export interface NutritionGoalsSourceResponse {
  source: GoalsSource;
  setAt: string | null;
  /** The trainer's display name when source is TRAINER; null if that account is gone. */
  setByName: string | null;
}

/** The trainer's view of the same fact: names are never sent, only whether the change was yours. */
export interface ClientNutritionGoalsSourceResponse {
  source: GoalsSource;
  setAt: string | null;
  setByYou: boolean;
}

/** What the client's own settings screen can say. */
export type ClientGoalsChip = { key: "byTrainerNamed"; name: string; at: string } | { key: "byTrainer"; at: string };

/** What the trainer's client tab can say. */
export type TrainerGoalsChip = { key: "byYou" | "byOtherTrainer" | "byClient"; at: string };

/** The client's own settings screen: only a *trainer's* change is worth a chip (the person already knows what they set). */
export function clientGoalsChip(r: NutritionGoalsSourceResponse | undefined): ClientGoalsChip | null {
  if (!r || r.source !== "TRAINER" || !r.setAt) return null;
  return r.setByName ? { key: "byTrainerNamed", name: r.setByName, at: r.setAt } : { key: "byTrainer", at: r.setAt };
}

/** The trainer's client tab: yours, another trainer's, or the client's own. */
export function trainerGoalsChip(r: ClientNutritionGoalsSourceResponse | undefined): TrainerGoalsChip | null {
  if (!r || r.source === "UNKNOWN" || !r.setAt) return null;
  if (r.source === "SELF") return { key: "byClient", at: r.setAt };
  return r.setByYou ? { key: "byYou", at: r.setAt } : { key: "byOtherTrainer", at: r.setAt };
}
