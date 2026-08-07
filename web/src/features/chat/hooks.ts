"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient, type QueryClient } from "@tanstack/react-query";
import { queryKeys } from "@/lib/api/queryKeys";
import { connectChatStream, type ChatStreamFrame } from "@/lib/api/chat-stream";
import { useSessionStore } from "@/features/auth/store";
import { chatApi } from "./api";
import { applyDeletion, mergeMessages, sortConversations, titleWithUnread, totalUnread } from "./thread";
import type {
  ConversationResponse,
  MessageDeletedEventPayload,
  MessageEventPayload,
  ReadEventPayload,
  ThreadMessage,
  TypingEventPayload,
} from "./types";

/**
 * How long an "is typing" stays on screen, and how often we tell the server we
 * are writing. Both mirror `lifey.chat.typing-ttl` / `typing-throttle`; the
 * throttle is shorter than the TTL on purpose, so a steady typist's indicator
 * is refreshed before it can lapse.
 */
export const TYPING_TTL_MS = 5_000;
export const TYPING_THROTTLE_MS = 3_000;

/**
 * Fallback refresh interval. Since I4 the stream carries the updates, so this
 * is a safety net for the cases the stream cannot cover — a second backend
 * instance whose in-memory event bus never saw the write, or a reconnect that
 * silently missed a frame — not the primary path it was in I3.
 */
export const CHAT_POLL_INTERVAL_MS = 60_000;

export function useConversations(enabled = true) {
  return useQuery({
    queryKey: queryKeys.chat.conversations(),
    queryFn: chatApi.conversations,
    select: (data): ConversationResponse[] => sortConversations(data.items),
    staleTime: 0,
    refetchInterval: CHAT_POLL_INTERVAL_MS,
    enabled,
  });
}

/**
 * Ambient unread signal for the whole trainer shell. Web push is out of the
 * first release, so the sidebar badge and the browser tab title are all the
 * trainer gets while the tab is in the background (§6.2).
 */
export function useUnreadTotal(): number {
  const user = useSessionStore((s) => s.user);
  const isTrainer = !!user?.roles.includes("ROLE_TRAINER");
  const { data } = useConversations(isTrainer);
  return data ? totalUnread(data) : 0;
}

/** Prefixes the tab title with the unread count — `(3) Lifey`. */
export function useUnreadDocumentTitle(unread: number) {
  useEffect(() => {
    const base = document.title.replace(/^\(\d+\)\s*/, "");
    document.title = titleWithUnread(base, unread);
    return () => {
      document.title = base;
    };
  }, [unread]);
}

/**
 * Holds the chat stream open for as long as the trainer shell is mounted, and
 * folds every frame into the query cache. Mounted once, in the admin layout,
 * so the sidebar badge stays live on every page — not only on /admin/chat.
 *
 * @returns whether the stream is currently connected
 */
export function useChatStream(enabled: boolean): boolean {
  const queryClient = useQueryClient();
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    if (!enabled) return;
    const disconnect = connectChatStream({
      onFrame: (frame) => applyFrame(queryClient, frame),
      onConnectionChange: setConnected,
    });
    return disconnect;
  }, [enabled, queryClient]);

  return connected;
}

function applyFrame(queryClient: QueryClient, frame: ChatStreamFrame) {
  if (frame.name === "message") {
    const payload = frame.data as MessageEventPayload;
    if (!payload?.message) return;

    // Only patch a thread that is already loaded: writing a cache entry for a
    // thread nobody has opened would leave a one-message "history" that the
    // keyset paging would then have to reconcile.
    const key = queryKeys.chat.messages(payload.conversationId);
    if (queryClient.getQueryData(key)) {
      queryClient.setQueryData<ThreadMessage[]>(key, (current) =>
        mergeMessages(current ?? [], [payload.message]),
      );
    }
    // The list needs the new ordering, preview and unread count, and deriving
    // all three locally would duplicate server rules for no gain — one refetch
    // per message is cheap next to the round trip we just avoided.
    queryClient.invalidateQueries({ queryKey: queryKeys.chat.conversations() });
    return;
  }

  if (frame.name === "read") {
    const payload = frame.data as ReadEventPayload;
    if (!payload) return;
    // Patched in place rather than invalidated: a receipt changes nothing but
    // the tick marks, and a refetch for that would be pure noise.
    queryClient.setQueryData<{ items: ConversationResponse[] }>(
      queryKeys.chat.conversations(),
      (current) =>
        current && {
          items: current.items.map((conversation) =>
            conversation.id === payload.conversationId
              ? {
                  ...conversation,
                  peerLastDeliveredMessageId: payload.lastDeliveredMessageId,
                  peerLastReadMessageId: payload.lastReadMessageId,
                }
              : conversation,
          ),
        },
    );
    return;
  }

  if (frame.name === "deleted") {
    const payload = frame.data as MessageDeletedEventPayload;
    if (!payload) return;

    // Same rule as a message frame: only patch a thread already in the cache.
    const key = queryKeys.chat.messages(payload.conversationId);
    if (queryClient.getQueryData(key)) {
      queryClient.setQueryData<ThreadMessage[]>(key, (current) =>
        applyDeletion(current ?? [], payload.messageId, payload.deletedAt),
      );
    }
    // The list carries the deleted message as its preview when it was the last
    // one, and the server decides that — same reasoning as for a new message.
    queryClient.invalidateQueries({ queryKey: queryKeys.chat.conversations() });
    return;
  }

  if (frame.name === "typing") {
    const payload = frame.data as TypingEventPayload;
    if (!payload) return;
    markPeerTyping(queryClient, payload.conversationId);
    return;
  }

  if (frame.name === "resync") {
    // The stream gave up on bridging the gap — the REST API is the truth.
    queryClient.invalidateQueries({ queryKey: ["chat"] });
  }
}

/**
 * One timer per thread, so a steady typist keeps the indicator alive with a
 * single pending timeout rather than a queue of them.
 */
const typingTimers = new Map<number, ReturnType<typeof setTimeout>>();

/**
 * Records that the peer is writing, and schedules its own expiry. The TTL is
 * owned here, in the one place frames arrive — a component that also had to
 * time it out would drift from this as soon as it remounted.
 */
function markPeerTyping(queryClient: QueryClient, conversationId: number) {
  const key = queryKeys.chat.typing(conversationId);
  queryClient.setQueryData<number>(key, Date.now());

  const pending = typingTimers.get(conversationId);
  if (pending) clearTimeout(pending);
  typingTimers.set(
    conversationId,
    setTimeout(() => {
      typingTimers.delete(conversationId);
      queryClient.setQueryData<number | null>(key, null);
    }, TYPING_TTL_MS),
  );
}

/**
 * Whether the peer is writing in this thread right now.
 *
 * Reads the cache entry the stream writes; there is no `queryFn` because there
 * is nothing to fetch — typing exists only as a frame, and the plan's "never a
 * state that lives only on the stream" rule survives because losing this costs
 * nothing at all (§19.4/1).
 */
export function usePeerTyping(conversationId: number): boolean {
  const { data } = useQuery<number | null>({
    queryKey: queryKeys.chat.typing(conversationId),
    queryFn: () => null,
    enabled: false,
    staleTime: Infinity,
    gcTime: TYPING_TTL_MS * 4,
  });
  return data != null;
}

/**
 * Sends "I'm writing" at most once per {@link TYPING_THROTTLE_MS}, and never
 * for an archived thread. Returns the function the composer calls on every
 * keystroke — the throttling is here so no caller has to remember it.
 */
export function useReportTyping(conversationId: number, enabled = true): () => void {
  const lastSentRef = useRef(0);

  useEffect(() => {
    // A thread switch has to reset the window, or the first keystroke in the
    // new thread is swallowed by the previous one's throttle.
    lastSentRef.current = 0;
  }, [conversationId]);

  return useCallback(() => {
    if (!enabled) return;
    const now = Date.now();
    if (now - lastSentRef.current < TYPING_THROTTLE_MS) return;
    lastSentRef.current = now;
    chatApi.typing(conversationId).catch(() => {
      // A dropped hint is invisible by design — the indicator simply doesn't
      // appear, which is the same as not typing.
    });
  }, [conversationId, enabled]);
}

/**
 * Tells the server which thread is on screen, so it can skip a push the reader
 * doesn't need (§5.1). Cleared when the thread closes and whenever the tab is
 * hidden — a background tab is not "looking at" anything.
 */
export function usePresence(conversationId: number | null) {
  useEffect(() => {
    const report = (id: number | null) => {
      chatApi.presence(id).catch(() => {
        // Presence is an optimisation. Losing it costs an unnecessary
        // notification, never a message, so a failure is not worth surfacing.
      });
    };

    const onVisibilityChange = () => report(document.hidden ? null : conversationId);

    report(document.hidden ? null : conversationId);
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => {
      document.removeEventListener("visibilitychange", onVisibilityChange);
      report(null);
    };
  }, [conversationId]);
}
