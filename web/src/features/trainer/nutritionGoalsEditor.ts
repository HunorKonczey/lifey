// Matches the backend cap (`ClientNutritionGoalsRequest`, `@PositiveOrZero`,
// docs/32-trainer-nutrition-goals-plan.md B2) — an empty field clears that
// goal, anything else must parse to a non-negative integer.

/** Empty input is valid (clears the goal); anything else must be a non-negative integer. */
export function isValidGoalInput(value: string): boolean {
  const trimmed = value.trim();
  return trimmed === "" || /^\d+$/.test(trimmed);
}

/** Empty input clears the goal (`null`); otherwise parses the integer. Assumes `isValidGoalInput` already passed. */
export function parseGoalInput(value: string): number | null {
  const trimmed = value.trim();
  return trimmed === "" ? null : parseInt(trimmed, 10);
}

/** `null`/`undefined` render as an empty (clearable) field. */
export function goalToInput(value: number | null | undefined): string {
  return value == null ? "" : String(value);
}
