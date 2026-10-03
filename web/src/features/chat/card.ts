import type { MessageCardPr, MessageCardResponse } from "./types";

/**
 * What a result card says, as plain numbers — the tile maps these to words and
 * formats them for the reader's locale (docs/chat/83-chat-result-card-plan.md §7).
 * Kept free of React so every rule here is a one-line test.
 */

/** The kinds this build can draw; anything else gets the "update the app" tile. */
export function isKnownCard(card: MessageCardResponse): boolean {
  if (card.kind === "WORKOUT") return card.workout !== null;
  if (card.kind === "PR") return card.pr !== null;
  return false;
}

/** Message-catalog key of the conversation-list preview for a card. */
export function cardPreviewKey(card: MessageCardResponse): "cardPreviewWorkout" | "cardPreviewRecord" {
  return card.kind === "PR" ? "cardPreviewRecord" : "cardPreviewWorkout";
}

export function isCardio(card: MessageCardResponse): boolean {
  return card.kind === "WORKOUT" && card.workout?.workoutKind === "CARDIO";
}

/** Whole minutes, at least one for any session that has a duration at all. */
export function durationMinutes(seconds: number | null | undefined): number | null {
  if (seconds == null || seconds <= 0) return null;
  return Math.max(1, Math.round(seconds / 60));
}

export function distanceKm(meters: number | null | undefined): number | null {
  if (meters == null || meters <= 0) return null;
  return meters / 1000;
}

/** The unit a record's number is in: reps for a reps record, kilograms otherwise. */
export function prUnit(pr: Pick<MessageCardPr, "prType">): "reps" | "kg" {
  return pr.prType === "REPS_AT_WEIGHT" ? "reps" : "kg";
}

/**
 * How far the record moved the old one, or null when there is nothing honest to
 * say: the exercise's first record, or no improvement. Rounded to one decimal so
 * 112.75 − 108.7 does not print as 4.049999….
 */
export function prDelta(pr: Pick<MessageCardPr, "value" | "previousValue">): number | null {
  if (pr.previousValue == null) return null;
  const delta = Math.round((pr.value - pr.previousValue) * 10) / 10;
  return delta > 0 ? delta : null;
}

/** How many records the workout produced; zero and unknown both draw nothing. */
export function recordCount(card: MessageCardResponse): number {
  return card.kind === "WORKOUT" ? (card.workout?.recordCount ?? 0) : 0;
}
