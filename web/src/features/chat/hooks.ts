"use client";

import { useEffect, useState } from "react";
import { useQuery, useQueryClient, type QueryClient } from "@tanstack/react-query";
import { queryKeys } from "@/lib/api/queryKeys";
import { connectChatStream, type ChatStreamFrame } from "@/lib/api/chat-stream";
import { useSessionStore } from "@/features/auth/store";
import { chatApi } from "./api";
import { mergeMessages, sortConversations, titleWithUnread, totalUnread } from "./thread";
import type {
  ConversationResponse,
  MessageEventPayload,
  ReadEventPayload,
  ThreadMessage,
} from "./types";

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

  if (frame.name === "resync") {
    // The stream gave up on bridging the gap — the REST API is the truth.
    queryClient.invalidateQueries({ queryKey: ["chat"] });
  }
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
