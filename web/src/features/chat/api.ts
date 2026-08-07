import { api } from "@/lib/api/client";
import type {
  ConversationListResponse,
  ConversationResponse,
  MessageListResponse,
  MessageResponse,
  SendMessageRequest,
} from "./types";

/**
 * `/chat/**`, deliberately not `/trainer/**`: the endpoints are shared with the
 * client-side app and authorize on participation in the thread, never on a role
 * (docs/chat/40-trainer-chat-plan.md §4). The web only exposes the trainer's
 * entry point to them, but the API itself is role-agnostic.
 */
export const chatApi = {
  conversations: () => api.get<ConversationListResponse>("/chat/conversations"),

  /** Lazy-create from the relationship id — the id the client detail page holds. */
  openConversation: (trainerClientId: number) =>
    api.post<ConversationResponse>("/chat/conversations", { trainerClientId }),

  /** Lazy-create from the peer's user id, for entry points that only know the user. */
  openConversationWithUser: (userId: number) =>
    api.post<ConversationResponse>(`/chat/conversations/with-user/${userId}`),

  /**
   * Keyset paging, always answered newest-first. `before` walks into history
   * (scroll up), `after` fills the gap above a known id after the tab was idle.
   * Offset paging isn't offered: a growing thread would shift rows between pages.
   */
  messages: (conversationId: number, params: { before?: number; after?: number; limit?: number } = {}) => {
    const search = new URLSearchParams();
    if (params.before != null) search.set("before", String(params.before));
    if (params.after != null) search.set("after", String(params.after));
    if (params.limit != null) search.set("limit", String(params.limit));
    const qs = search.toString();
    return api.get<MessageListResponse>(
      `/chat/conversations/${conversationId}/messages${qs ? `?${qs}` : ""}`,
    );
  },

  /** Idempotent on clientMessageId: replaying the same id returns the stored message. */
  send: (conversationId: number, body: SendMessageRequest) =>
    api.post<MessageResponse>(`/chat/conversations/${conversationId}/messages`, body),

  /**
   * The same send with an image, as multipart. One request rather than
   * "create, then attach": the same `clientMessageId` still makes a retry
   * idempotent, and there is never a half-sent message on the other side.
   */
  sendWithAttachment: (
    conversationId: number,
    { file, body, clientMessageId }: { file: File; body: string; clientMessageId: string },
  ) => {
    const formData = new FormData();
    formData.append("file", file);
    if (body) formData.append("body", body);
    formData.append("clientMessageId", clientMessageId);
    return api.postForm<MessageResponse>(`/chat/conversations/${conversationId}/messages`, formData);
  },

  /** Bubble-sized image. 404 for a message without one, same as for a stranger's thread. */
  attachmentThumbnail: (messageId: number) =>
    api.getBlob(`/chat/messages/${messageId}/attachment/thumbnail`),

  /** Full-size image, fetched only when someone opens the picture. */
  attachment: (messageId: number) => api.getBlob(`/chat/messages/${messageId}/attachment`),

  /** Tombstone, not a hard delete — only your own message. */
  deleteMessage: (messageId: number) => api.delete(`/chat/messages/${messageId}`),

  /** Monotonic and clamped server-side, so a stale cursor is harmless. */
  markRead: (conversationId: number, lastReadMessageId: number) =>
    api.post<void>(`/chat/conversations/${conversationId}/read`, { lastReadMessageId }),

  /** "I'm looking at this thread" — null when leaving it or hiding the tab (§5.1). */
  presence: (activeConversationId: number | null) =>
    api.post<void>("/chat/presence", { activeConversationId }),

  /** Silences this thread's pushes until the given instant; null unmutes (§I5). */
  mute: (conversationId: number, mutedUntil: string | null) =>
    api.put<void>(`/chat/conversations/${conversationId}/mute`, { mutedUntil }),
};
