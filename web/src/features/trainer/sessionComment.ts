// Matches the backend cap (`SessionCommentRequest.comment`, `@Size(max = 2000)`,
// docs/31-session-feedback-loop-plan.md B2) so the composer can disable Save
// before a doomed request round-trips.
export const MAX_COMMENT_LENGTH = 2000;

/** Trims the draft and returns null when there's nothing worth sending. */
export function trimCommentForSave(draft: string): string | null {
  const trimmed = draft.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function isCommentSaveable(draft: string): boolean {
  const trimmed = draft.trim();
  return trimmed.length > 0 && trimmed.length <= MAX_COMMENT_LENGTH;
}
