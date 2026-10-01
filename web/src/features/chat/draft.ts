import type { ConversationResponse } from "./types";

/** The query parameter the trainer chat page reads a prefilled draft from. */
export const DRAFT_PARAM = "draft";

/**
 * A link into the trainer chat with a message waiting in the composer — never sent automatically: the trainer reads it,
 * edits it and presses send. Returns null when this client has no conversation yet (the caller then falls back to the
 * plain chat page).
 */
export function chatDraftHref(conversations: ConversationResponse[] | undefined, clientId: number, draft: string): string | null {
  const conversation = conversations?.find((c) => c.peer.userId === clientId);
  if (!conversation) return null;
  return `/admin/chat?c=${conversation.id}&${DRAFT_PARAM}=${encodeURIComponent(draft)}`;
}

/** The first word of a person's display name, for a greeting ("Nagy Kata" → "Nagy" is wrong in HU, so the caller passes the first name). */
export function greetingName(firstName: string | null | undefined, displayName: string): string {
  const first = (firstName ?? "").trim();
  return first || displayName.split(/\s+/)[0] || displayName;
}
