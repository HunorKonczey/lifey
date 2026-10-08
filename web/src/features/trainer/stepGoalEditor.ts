// The step goal the trainer sets for a client (LIF-105). Matches the backend (`ClientStepGoalRequest`, `@Positive`):
// an empty field clears the goal, anything else must be a whole number above zero.

/** Empty input is valid (clears the goal); anything else must be a whole number above zero. */
export function isValidStepGoalInput(value: string): boolean {
  const trimmed = value.trim();
  return trimmed === "" || (/^\d+$/.test(trimmed) && parseInt(trimmed, 10) > 0);
}

/** Empty input clears the goal (`null`); otherwise parses the integer. Assumes `isValidStepGoalInput` already passed. */
export function parseStepGoalInput(value: string): number | null {
  const trimmed = value.trim();
  return trimmed === "" ? null : parseInt(trimmed, 10);
}
