/**
 * Mirrors `com.lifey.chat.dto` as delivered in I1/I2 — see
 * docs/chat/40-trainer-chat-plan.md §12.2 and §13.2 for the places where the
 * shipped contract differs from the plan's §4 sketch.
 */

/** What the peer is *to the caller*, not a global role (§6.1). */
export type ChatPeerRole = "TRAINER" | "CLIENT";

export interface ChatPeerResponse {
  userId: number;
  displayName: string;
  email: string;
  role: ChatPeerRole;
}

/** `body` is null exactly when `deletedAt` is set — the tombstone text is ours to localize. */
export interface MessageResponse {
  id: number;
  conversationId: number;
  senderId: number;
  body: string | null;
  clientMessageId: string;
  createdAt: string;
  deletedAt: string | null;
}

export interface ConversationResponse {
  id: number;
  peer: ChatPeerResponse;
  /** Null until the first message; otherwise the full message shape, not a preview. */
  lastMessage: MessageResponse | null;
  unreadCount: number;
  archivedAt: string | null;
  /**
   * How far the peer has got in this thread — the two numbers the sender's tick
   * marks are drawn from. Per participant, not per message, which is why they
   * live here and not on `MessageResponse`. Live updates arrive as `read`
   * frames on the stream.
   */
  peerLastDeliveredMessageId: number | null;
  peerLastReadMessageId: number | null;
  /**
   * The caller's *own* mute for this thread — the one per-participant field
   * that describes the viewer rather than the peer. Null or in the past means
   * not muted; the instant expires on its own (§I5).
   */
  mutedUntil: string | null;
}

export interface ConversationListResponse {
  items: ConversationResponse[];
}

export interface MessageListResponse {
  items: MessageResponse[];
  hasMore: boolean;
}

export interface SendMessageRequest {
  body: string;
  clientMessageId: string;
}

/** Body of an `event: message` frame on the SSE stream. */
export interface MessageEventPayload {
  conversationId: number;
  message: MessageResponse;
}

/** Body of an `event: read` frame — the *peer's* cursors, never your own. */
export interface ReadEventPayload {
  conversationId: number;
  userId: number;
  lastDeliveredMessageId: number | null;
  lastReadMessageId: number | null;
}

/**
 * A message as the thread renders it. The server shape plus the local send
 * state: web mirrors mobile's optimistic send (§13.4/2), so a bubble exists
 * before the POST resolves and keeps its identity through the server echo.
 *
 * `delivered` and `read` are not stored on the message — they are derived by
 * comparing its id against the conversation's peer cursors (see
 * `receiptStateFor`), because that is the shape the server keeps them in.
 */
export type ChatMessageState = "pending" | "sent" | "failed";

/** What a sender's tick marks can say about one of their own messages. */
export type ChatReceiptState = ChatMessageState | "delivered" | "read";

export interface ThreadMessage extends Omit<MessageResponse, "id"> {
  /** Null while the message only exists locally (pending or failed). */
  id: number | null;
  state: ChatMessageState;
}
