import { describe, it, expect } from "vitest";
import {
  MAX_MESSAGE_LENGTH,
  applyDeletion,
  hasImage,
  highlightSegments,
  buildThreadItems,
  filterConversations,
  hasMixedPeerRoles,
  isMessageSendable,
  isMuted,
  muteUntil,
  mergeMessages,
  newestMessageId,
  oldestMessageId,
  receiptStateFor,
  sortConversations,
  titleWithUnread,
  totalUnread,
  trimMessageForSend,
  unreadBadgeLabel,
} from "./thread";
import type { ConversationResponse, MessageResponse, ThreadMessage } from "./types";

function serverMessage(over: Partial<MessageResponse> & { id: number }): MessageResponse {
  return {
    conversationId: 12,
    senderId: 7,
    body: "hello",
    clientMessageId: `c${over.id}`,
    createdAt: "2026-08-06T09:00:00Z",
    deletedAt: null,
    attachment: null,
    ...over,
  };
}

function pending(clientMessageId: string, over: Partial<ThreadMessage> = {}): ThreadMessage {
  return {
    id: null,
    conversationId: 12,
    senderId: 7,
    body: "unsent",
    clientMessageId,
    createdAt: "2026-08-06T10:00:00Z",
    deletedAt: null,
    attachment: null,
    state: "pending",
    ...over,
  };
}

function conversation(over: Partial<ConversationResponse> & { id: number }): ConversationResponse {
  return {
    peer: { userId: 88, displayName: "Nagy Petra", email: "petra@lifey.app", role: "CLIENT" },
    lastMessage: null,
    unreadCount: 0,
    archivedAt: null,
    peerLastDeliveredMessageId: null,
    peerLastReadMessageId: null,
    mutedUntil: null,
    ...over,
  };
}

function sent(id: number): ThreadMessage {
  return { ...serverMessage({ id }), state: "sent" };
}

describe("trimMessageForSend / isMessageSendable", () => {
  it("trims surrounding whitespace", () => {
    expect(trimMessageForSend("  Holnap 17:00 jó?  ")).toBe("Holnap 17:00 jó?");
  });

  it("treats a blank body as nothing to send", () => {
    expect(trimMessageForSend("   \n ")).toBeNull();
    expect(isMessageSendable("   ")).toBe(false);
  });

  it("accepts a body at the cap and rejects one over it", () => {
    expect(isMessageSendable("a".repeat(MAX_MESSAGE_LENGTH))).toBe(true);
    expect(isMessageSendable("a".repeat(MAX_MESSAGE_LENGTH + 1))).toBe(false);
  });
});

describe("highlightSegments", () => {
  const shown = (segments: { text: string; match: boolean }[]) =>
    segments.map((s) => (s.match ? `[${s.text}]` : s.text)).join("");

  it("marks the hit and leaves the rest alone", () => {
    expect(shown(highlightSegments("Holnap lábnap lesz", "lábnap"))).toBe("Holnap [lábnap] lesz");
  });

  it("matches without accents or case, but highlights the original text", () => {
    // The server searches through `unaccent`, so a hit can look nothing like
    // the term — highlighting nothing in a returned result reads as a bug.
    expect(shown(highlightSegments("Holnap Lábnap lesz", "labnap"))).toBe("Holnap [Lábnap] lesz");
  });

  it("marks every occurrence, not just the first", () => {
    expect(shown(highlightSegments("szett, szett, szett", "szett"))).toBe("[szett], [szett], [szett]");
  });

  it("keeps the original string intact across accented matches", () => {
    // The folded form of "ő" is longer than the original: an index mapped from
    // the folded string would slice in the wrong place without the map.
    const segments = highlightSegments("Erősítő nap", "erosito");
    expect(segments.map((s) => s.text).join("")).toBe("Erősítő nap");
    expect(shown(segments)).toBe("[Erősítő] nap");
  });

  it("returns the text untouched for an empty term", () => {
    expect(highlightSegments("bármi", "  ")).toEqual([{ text: "bármi", match: false }]);
  });

  it("returns the text untouched when nothing matches", () => {
    expect(highlightSegments("bármi", "zzz")).toEqual([{ text: "bármi", match: false }]);
  });
});

describe("image attachments", () => {
  const withImage = (over: Partial<ThreadMessage> = {}): ThreadMessage => ({
    ...serverMessage({ id: 30 }),
    state: "sent",
    attachment: { width: 1600, height: 900, byteSize: 120_000 },
    ...over,
  });

  it("counts a stored picture and one still uploading alike", () => {
    expect(hasImage(withImage())).toBe(true);
    expect(hasImage(pending("abc", { localImageUrl: "blob:local" }))).toBe(true);
    expect(hasImage(pending("abc"))).toBe(false);
  });

  it("lets a picture go without a caption, but never text on its own", () => {
    expect(isMessageSendable("", true)).toBe(true);
    expect(isMessageSendable("   ", true)).toBe(true);
    expect(isMessageSendable("", false)).toBe(false);
    // The length cap still applies to a caption.
    expect(isMessageSendable("x".repeat(MAX_MESSAGE_LENGTH + 1), true)).toBe(false);
  });

  it("keeps the local preview through the server echo, so the picture doesn't blink", () => {
    const optimistic = [pending("abc", { localImageUrl: "blob:local" })];

    const merged = mergeMessages(optimistic, [
      serverMessage({ id: 4310, clientMessageId: "abc", body: null }),
    ]);

    expect(merged[0].id).toBe(4310);
    expect(merged[0].localImageUrl).toBe("blob:local");
  });
});

describe("applyDeletion", () => {
  const stored = (id: number, over: Partial<ThreadMessage> = {}): ThreadMessage => ({
    ...serverMessage({ id }),
    state: "sent",
    ...over,
  });

  it("clears the text but keeps the row, so the replies around it still make sense", () => {
    const after = applyDeletion([stored(30), stored(31)], 30, "2026-08-07T10:00:00Z");

    expect(after).toHaveLength(2);
    expect(after[0]).toMatchObject({ id: 30, body: null, deletedAt: "2026-08-07T10:00:00Z" });
    expect(after[1].body).toBe("hello");
  });

  it("is a no-op on a message already tombstoned, so the frame echoed back changes nothing", () => {
    const messages = [stored(30, { body: null, deletedAt: "2026-08-07T10:00:00Z" })];

    // Same array back: the tab that performed the deletion also receives the
    // frame for it, and a fresh array there would rerender the whole thread.
    expect(applyDeletion(messages, 30, "2026-08-07T10:00:05Z")).toBe(messages);
  });

  it("leaves a thread that never held the message untouched", () => {
    const messages = [stored(30)];

    expect(applyDeletion(messages, 999, "2026-08-07T10:00:00Z")).toBe(messages);
  });
});

describe("mergeMessages", () => {
  it("replaces the optimistic row with the server echo instead of duplicating it", () => {
    const optimistic = [pending("abc")];
    const merged = mergeMessages(optimistic, [
      serverMessage({ id: 4310, clientMessageId: "abc", body: "unsent" }),
    ]);

    expect(merged).toHaveLength(1);
    expect(merged[0].id).toBe(4310);
    expect(merged[0].state).toBe("sent");
  });

  it("stitches an older page onto the thread without gaps or repeats", () => {
    const existing = [serverMessage({ id: 30 }), serverMessage({ id: 31 })].map((m) => ({
      ...m,
      state: "sent" as const,
    }));
    const merged = mergeMessages(existing, [
      serverMessage({ id: 29 }),
      serverMessage({ id: 30 }),
    ]);

    expect(merged.map((m) => m.id)).toEqual([29, 30, 31]);
  });

  it("keeps unsent messages after every stored one", () => {
    const merged = mergeMessages(
      [pending("later", { createdAt: "2026-08-06T08:00:00Z" })],
      [serverMessage({ id: 4310, createdAt: "2026-08-06T09:00:00Z" })],
    );

    expect(merged.map((m) => m.id)).toEqual([4310, null]);
  });

  it("reports the keyset anchors", () => {
    const merged = mergeMessages([pending("p")], [serverMessage({ id: 7 }), serverMessage({ id: 9 })]);
    expect(newestMessageId(merged)).toBe(9);
    expect(oldestMessageId(merged)).toBe(7);
  });
});

describe("buildThreadItems", () => {
  const own = 7;

  it("inserts a day divider ahead of the first message of each local day", () => {
    const items = buildThreadItems(
      mergeMessages([], [
        serverMessage({ id: 1, createdAt: "2026-08-05T09:00:00Z" }),
        serverMessage({ id: 2, createdAt: "2026-08-06T09:00:00Z" }),
      ]),
      own,
    );

    expect(items.filter((i) => i.kind === "day")).toHaveLength(2);
    expect(items[0].kind).toBe("day");
  });

  it("groups a same-sender run so only its last bubble carries time and state", () => {
    const items = buildThreadItems(
      mergeMessages([], [
        serverMessage({ id: 1, senderId: 7 }),
        serverMessage({ id: 2, senderId: 7 }),
        serverMessage({ id: 3, senderId: 88 }),
      ]),
      own,
    );
    const messages = items.filter((i) => i.kind === "message");

    expect(messages.map((m) => [m.groupStart, m.groupEnd])).toEqual([
      [true, false],
      [false, true],
      [true, true],
    ]);
    expect(messages.map((m) => m.own)).toEqual([true, true, false]);
  });

  it("breaks a run at a day boundary even for the same sender", () => {
    const items = buildThreadItems(
      mergeMessages([], [
        serverMessage({ id: 1, senderId: 7, createdAt: "2026-08-05T09:00:00Z" }),
        serverMessage({ id: 2, senderId: 7, createdAt: "2026-08-06T09:00:00Z" }),
      ]),
      own,
    );
    const messages = items.filter((i) => i.kind === "message");

    expect(messages.every((m) => m.groupStart && m.groupEnd)).toBe(true);
  });
});

describe("receiptStateFor", () => {
  it("is read at or below the peer's read cursor", () => {
    expect(receiptStateFor(sent(100), 120, 100)).toBe("read");
    expect(receiptStateFor(sent(99), 120, 100)).toBe("read");
  });

  it("is delivered above the read cursor but at or below the delivered one", () => {
    expect(receiptStateFor(sent(110), 120, 100)).toBe("delivered");
    expect(receiptStateFor(sent(120), 120, 100)).toBe("delivered");
  });

  it("is only sent above both cursors, and with no cursors at all", () => {
    expect(receiptStateFor(sent(130), 120, 100)).toBe("sent");
    expect(receiptStateFor(sent(130), null, null)).toBe("sent");
  });

  it("leaves local states alone, so a cursor can never dress up an unsent message", () => {
    expect(receiptStateFor(pending("p"), 999, 999)).toBe("pending");
    expect(receiptStateFor(pending("f", { state: "failed" }), 999, 999)).toBe("failed");
  });
});

describe("sortConversations", () => {
  it("puts the newest activity first and threads without a message last", () => {
    const sorted = sortConversations([
      conversation({ id: 1, lastMessage: serverMessage({ id: 10, createdAt: "2026-08-01T09:00:00Z" }) }),
      conversation({ id: 2 }),
      conversation({ id: 3, lastMessage: serverMessage({ id: 11, createdAt: "2026-08-06T09:00:00Z" }) }),
    ]);

    expect(sorted.map((c) => c.id)).toEqual([3, 1, 2]);
  });
});

describe("filterConversations", () => {
  const items = [
    conversation({ id: 1, peer: { userId: 1, displayName: "Nagy Petra", email: "petra@lifey.app", role: "CLIENT" } }),
    conversation({ id: 2, peer: { userId: 2, displayName: "Tóth Eszter", email: "eszter@lifey.app", role: "CLIENT" } }),
  ];

  it("matches on name regardless of case and accents", () => {
    expect(filterConversations(items, "toth").map((c) => c.id)).toEqual([2]);
    expect(filterConversations(items, "PETRA").map((c) => c.id)).toEqual([1]);
  });

  it("matches on e-mail and returns everything for a blank query", () => {
    expect(filterConversations(items, "eszter@").map((c) => c.id)).toEqual([2]);
    expect(filterConversations(items, "  ")).toHaveLength(2);
  });
});

describe("hasMixedPeerRoles", () => {
  const client = conversation({ id: 1 });
  const trainer = conversation({
    id: 2,
    peer: { userId: 3, displayName: "Kovács Máté", email: "mate@lifey.app", role: "TRAINER" },
  });

  it("is false for a list of one kind", () => {
    expect(hasMixedPeerRoles([client, conversation({ id: 4 })])).toBe(false);
    expect(hasMixedPeerRoles([trainer])).toBe(false);
  });

  it("is true once both kinds appear", () => {
    expect(hasMixedPeerRoles([client, trainer])).toBe(true);
  });
});

describe("isMuted / muteUntil", () => {
  const now = new Date("2026-08-06T12:00:00Z");

  it("treats a future instant as muted and a past one as expired", () => {
    // A mute is an instant, not a flag, so it lapses without anything sweeping it.
    expect(isMuted("2026-08-06T13:00:00Z", now)).toBe(true);
    expect(isMuted("2026-08-06T11:59:59Z", now)).toBe(false);
    expect(isMuted(null, now)).toBe(false);
  });

  it("builds the instant the chosen duration lands on", () => {
    expect(muteUntil(1, now)).toBe("2026-08-06T13:00:00.000Z");
    expect(muteUntil(8, now)).toBe("2026-08-06T20:00:00.000Z");
  });

  it("expresses 'until I turn it back on' as a far-future instant", () => {
    // Far enough out that no separate "forever" flag is needed anywhere.
    expect(isMuted(muteUntil(null, now), now)).toBe(true);
    expect(new Date(muteUntil(null, now)).getUTCFullYear()).toBe(2036);
  });
});

describe("unread signalling", () => {
  it("sums unread across threads", () => {
    expect(totalUnread([conversation({ id: 1, unreadCount: 2 }), conversation({ id: 2, unreadCount: 1 })])).toBe(3);
  });

  it("badges the tab title only when something is unread", () => {
    expect(titleWithUnread("Lifey", 3)).toBe("(3) Lifey");
    expect(titleWithUnread("Lifey", 0)).toBe("Lifey");
  });

  it("caps the row badge at 9+", () => {
    expect(unreadBadgeLabel(9)).toBe("9");
    expect(unreadBadgeLabel(12)).toBe("9+");
  });
});
