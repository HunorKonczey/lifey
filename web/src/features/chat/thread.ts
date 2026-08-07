import type {
  ChatReceiptState,
  ConversationResponse,
  MessageResponse,
  ThreadMessage,
} from "./types";

/** Mirrors `lifey.chat.max-body-length` (application.yml); enforced after trimming. */
export const MAX_MESSAGE_LENGTH = 2000;

/** Keyset page size for GET /chat/conversations/{id}/messages — the server default. */
export const MESSAGE_PAGE_SIZE = 30;

export function trimMessageForSend(raw: string): string | null {
  const trimmed = raw.trim();
  return trimmed.length === 0 ? null : trimmed;
}

/** Mirrors `lifey.chat.attachment-max-bytes`; checked before the upload starts. */
export const MAX_ATTACHMENT_BYTES = 8 * 1024 * 1024;

/** What the file picker offers, and what the server's decoder actually accepts. */
export const ACCEPTED_IMAGE_TYPES = "image/jpeg,image/png,image/webp";

/**
 * A picture on its own is a complete message, so the caption may be empty —
 * but text alone still has to be non-blank.
 */
export function isMessageSendable(raw: string, withImage = false): boolean {
  const trimmed = trimMessageForSend(raw);
  if (trimmed === null) return withImage;
  return trimmed.length <= MAX_MESSAGE_LENGTH;
}

/**
 * Idempotency key for a send. The same id must be reused on retry — that is
 * what makes a blind resend safe (§12.4), and it is also how the server echo
 * finds and replaces the optimistic row.
 */
export function newClientMessageId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

export function toThreadMessage(message: MessageResponse): ThreadMessage {
  return { ...message, state: "sent" };
}

/**
 * Sort order for the rendered thread: stored messages by server id (the only
 * total order the backend guarantees), unsent ones after them. A `failed`
 * bubble therefore stays parked at the bottom next to its retry action instead
 * of sliding back into history on the next refresh.
 */
function compareMessages(a: ThreadMessage, b: ThreadMessage): number {
  if (a.id != null && b.id != null) return a.id - b.id;
  if (a.id != null) return -1;
  if (b.id != null) return 1;
  const byTime = Date.parse(a.createdAt) - Date.parse(b.createdAt);
  return byTime !== 0 ? byTime : a.clientMessageId.localeCompare(b.clientMessageId);
}

/**
 * Fold a server page into what the thread already holds, keyed on
 * `clientMessageId` (unique per conversation, and carried by both sides'
 * messages). The incoming row wins, which is how the server echo turns a
 * `pending` bubble into a real message rather than duplicating it (§13.4/3).
 */
export function mergeMessages(
  existing: ThreadMessage[],
  incoming: MessageResponse[],
): ThreadMessage[] {
  const byClientId = new Map<string, ThreadMessage>();
  for (const message of existing) byClientId.set(message.clientMessageId, message);
  for (const message of incoming) {
    const previous = byClientId.get(message.clientMessageId);
    byClientId.set(message.clientMessageId, {
      ...toThreadMessage(message),
      // The picked file's object URL survives the echo so the picture doesn't
      // blink out and back in while the server thumbnail loads. `localFile`
      // does not: the upload succeeded, and holding the bytes would keep every
      // image sent this session in memory.
      localImageUrl: previous?.localImageUrl,
    });
  }
  return [...byClientId.values()].sort(compareMessages);
}

/** Whether this message shows a picture — stored, or still being uploaded. */
export function hasImage(message: ThreadMessage): boolean {
  return message.attachment !== null || message.localImageUrl !== undefined;
}

/**
 * Turn one already-held message into a tombstone: the row stays so the other
 * side keeps the context of their replies, the text goes.
 *
 * Kept separate from `mergeMessages` because a deletion is not a page of
 * messages — it is the one change that reaches back into rows the gap fill
 * (`after=<id>`) will never look at again. Returns the same array when nothing
 * matched, so a frame for a thread the browser never opened costs no rerender.
 */
export function applyDeletion(
  messages: ThreadMessage[],
  messageId: number,
  deletedAt: string,
): ThreadMessage[] {
  if (!messages.some((message) => message.id === messageId && message.deletedAt === null)) {
    return messages;
  }
  return messages.map((message) =>
    message.id === messageId ? { ...message, body: null, deletedAt } : message,
  );
}

/** Highest stored id — the read cursor, and the `after=` anchor for gap fills. */
export function newestMessageId(messages: ThreadMessage[]): number | null {
  let newest: number | null = null;
  for (const message of messages) {
    if (message.id != null && (newest === null || message.id > newest)) newest = message.id;
  }
  return newest;
}

/** Lowest stored id — the `before=` anchor when scrolling into history. */
export function oldestMessageId(messages: ThreadMessage[]): number | null {
  let oldest: number | null = null;
  for (const message of messages) {
    if (message.id != null && (oldest === null || message.id < oldest)) oldest = message.id;
  }
  return oldest;
}

/** Local calendar day of an instant, as `YYYY-MM-DD` — the day-divider key. */
export function dayKey(isoInstant: string): string {
  const date = new Date(isoInstant);
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${date.getFullYear()}-${month}-${day}`;
}

export type ThreadItem =
  | { kind: "day"; key: string; day: string; at: string }
  | {
      kind: "message";
      key: string;
      message: ThreadMessage;
      own: boolean;
      /** First of a same-sender run: the one that gets the extra top margin. */
      groupStart: boolean;
      /** Last of a same-sender run: the only one showing avatar, time and state. */
      groupEnd: boolean;
    };

/**
 * Turns the flat message list into what the thread renders: day dividers plus
 * runs of same-sender bubbles. Grouping breaks on a sender change and on a day
 * boundary, so a run never spans a divider (§A3 of the design brief).
 */
export function buildThreadItems(messages: ThreadMessage[], ownUserId: number): ThreadItem[] {
  const items: ThreadItem[] = [];
  let previousDay: string | null = null;

  messages.forEach((message, index) => {
    const day = dayKey(message.createdAt);
    if (day !== previousDay) {
      items.push({ kind: "day", key: `day-${day}`, day, at: message.createdAt });
      previousDay = day;
    }

    const previous = index > 0 ? messages[index - 1] : null;
    const next = index < messages.length - 1 ? messages[index + 1] : null;
    const sameRunAsPrevious =
      previous !== null &&
      previous.senderId === message.senderId &&
      dayKey(previous.createdAt) === day;
    const sameRunAsNext =
      next !== null && next.senderId === message.senderId && dayKey(next.createdAt) === day;

    items.push({
      kind: "message",
      key: message.clientMessageId,
      message,
      own: message.senderId === ownUserId,
      groupStart: !sameRunAsPrevious,
      groupEnd: !sameRunAsNext,
    });
  });

  return items;
}

/**
 * The tick mark for one of your own messages. Derived rather than stored: the
 * server keeps delivery and reading as two per-participant cursors, so "has
 * this message been read" is the question "is its id at or below the peer's
 * read cursor" (§3.1).
 *
 * Messages that never reached the server keep their local state — a `pending`
 * bubble has no id to compare, and a `failed` one must not be dressed up as
 * delivered by a cursor that moved for some other message.
 */
export function receiptStateFor(
  message: ThreadMessage,
  peerLastDeliveredMessageId: number | null,
  peerLastReadMessageId: number | null,
): ChatReceiptState {
  if (message.state !== "sent" || message.id === null) return message.state;
  if (peerLastReadMessageId !== null && message.id <= peerLastReadMessageId) return "read";
  if (peerLastDeliveredMessageId !== null && message.id <= peerLastDeliveredMessageId) return "delivered";
  return "sent";
}

/** Newest activity first, threads without a message last — the server's order, reapplied locally. */
export function sortConversations(items: ConversationResponse[]): ConversationResponse[] {
  return [...items].sort((a, b) => {
    const aAt = a.lastMessage ? Date.parse(a.lastMessage.createdAt) : null;
    const bAt = b.lastMessage ? Date.parse(b.lastMessage.createdAt) : null;
    if (aAt === null && bAt === null) return b.id - a.id;
    if (aAt === null) return 1;
    if (bAt === null) return -1;
    return bAt !== aAt ? bAt - aAt : b.id - a.id;
  });
}

/** Case- and accent-insensitive match on the peer's name and e-mail. */
export function filterConversations(
  items: ConversationResponse[],
  query: string,
): ConversationResponse[] {
  const needle = normalize(query);
  if (!needle) return items;
  return items.filter(
    (c) => normalize(c.peer.displayName).includes(needle) || normalize(c.peer.email).includes(needle),
  );
}

function normalize(value: string): string {
  return value.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase().trim();
}

/**
 * True when the list holds both kinds of peer — a trainer who also has a
 * trainer of their own. Only then is the "Your trainer" / "Your client" row
 * label shown: on a pure client list it would be noise on every row (§13.4/4).
 */
export function hasMixedPeerRoles(items: ConversationResponse[]): boolean {
  return (
    items.some((c) => c.peer.role === "TRAINER") && items.some((c) => c.peer.role === "CLIENT")
  );
}

export function totalUnread(items: ConversationResponse[]): number {
  return items.reduce((sum, c) => sum + c.unreadCount, 0);
}

/**
 * Browser-tab badge. Web push is deliberately out of the first release, so the
 * tab title is the only ambient signal the trainer gets (§6.2).
 */
export function titleWithUnread(base: string, unread: number): string {
  return unread > 0 ? `(${unread}) ${base}` : base;
}

/**
 * A mute is an instant, not a flag, so it expires without anything sweeping it
 * — which means "is this muted" is always a comparison against now, never a
 * stored boolean that could go stale.
 */
export function isMuted(mutedUntil: string | null, now: Date = new Date()): boolean {
  return mutedUntil !== null && Date.parse(mutedUntil) > now.getTime();
}

/** Fixed mute durations offered in the thread menu; null means "until I unmute". */
export const MUTE_DURATIONS_HOURS = [1, 8] as const;

/** Far enough out to read as "off" without needing a separate forever flag. */
export const MUTE_FOREVER_YEARS = 10;

export function muteUntil(hours: number | null, now: Date = new Date()): string {
  const target = new Date(now);
  if (hours === null) target.setFullYear(target.getFullYear() + MUTE_FOREVER_YEARS);
  else target.setTime(target.getTime() + hours * 60 * 60 * 1000);
  return target.toISOString();
}

/** Conversation-list badge cap; the design shows "9+" above nine. */
export function unreadBadgeLabel(unread: number): string {
  return unread > 9 ? "9+" : String(unread);
}
