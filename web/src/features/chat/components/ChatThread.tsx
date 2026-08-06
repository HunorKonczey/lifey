"use client";

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format, isToday, isYesterday } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { queryKeys } from "@/lib/api/queryKeys";
import { ApiError } from "@/lib/api/client";
import { useLocale } from "@/lib/hooks/useLocale";
import { useToast } from "@/lib/hooks/useToast";
import { ErrorState } from "@/components/status/ErrorState";
import { EmptyState } from "@/components/status/EmptyState";
import { ChatAvatar } from "./ChatAvatar";
import { ArchivedComposerNotice, ChatComposer } from "./ChatComposer";
import { MessageBubble } from "./MessageBubble";
import { chatApi } from "../api";
import { CHAT_POLL_INTERVAL_MS } from "../hooks";
import {
  MESSAGE_PAGE_SIZE,
  buildThreadItems,
  mergeMessages,
  newClientMessageId,
  MUTE_DURATIONS_HOURS,
  isMuted,
  muteUntil,
  newestMessageId,
  oldestMessageId,
  receiptStateFor,
} from "../thread";
import type { ConversationResponse, MessageResponse, ThreadMessage } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

interface ChatThreadProps {
  conversation: ConversationResponse;
  ownUserId: number;
  /** Rendered only below the two-column breakpoint, where the thread replaces the list. */
  onBack?: () => void;
}

export function ChatThread({ conversation, ownUserId, onBack }: ChatThreadProps) {
  const t = useTranslations("chat");
  const locale = useLocale((s) => s.locale);
  const queryClient = useQueryClient();
  const { show } = useToast();
  const conversationId = conversation.id;
  const messagesKey = queryKeys.chat.messages(conversationId);

  const scrollRef = useRef<HTMLDivElement>(null);
  const [hasMore, setHasMore] = useState(true);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const acknowledgedRef = useRef<number | null>(null);

  const readMessages = useCallback(
    () => queryClient.getQueryData<ThreadMessage[]>(messagesKey) ?? [],
    [queryClient, messagesKey],
  );

  /**
   * One query owns the thread, and its own result is its input: it asks for
   * everything `after` the newest id it already holds, so a refresh is a gap
   * fill rather than a re-download of the page. Without a cursor (first open,
   * or after the cache was evicted) it falls back to the newest page.
   *
   * Since I4 the stream writes into this same cache entry, and the interval is
   * only the backstop for what the stream cannot cover.
   */
  const { data: messages, isLoading, isError, refetch } = useQuery({
    queryKey: messagesKey,
    queryFn: async () => {
      const existing = readMessages();
      const after = newestMessageId(existing);
      const page = await chatApi.messages(
        conversationId,
        after != null ? { after } : { limit: MESSAGE_PAGE_SIZE },
      );
      if (after == null) setHasMore(page.hasMore);
      return mergeMessages(existing, page.items);
    },
    staleTime: 0,
    refetchInterval: CHAT_POLL_INTERVAL_MS,
  });

  // The page keys this component on the conversation id, so switching threads
  // remounts it — `hasMore` and the read cursor start fresh without an effect.
  const thread = messages ?? [];
  const newestId = newestMessageId(thread);

  /**
   * Acknowledge up to the newest stored message whenever it moves. The server
   * clamps and only ever advances the cursor, so re-sending a stale id is
   * harmless — which is why this needs no coordination with the poll.
   */
  useEffect(() => {
    if (newestId == null || acknowledgedRef.current === newestId) return;
    acknowledgedRef.current = newestId;
    chatApi
      .markRead(conversationId, newestId)
      .then(() => queryClient.invalidateQueries({ queryKey: queryKeys.chat.conversations() }))
      .catch(() => {
        // A dropped receipt only costs an unread badge that clears on the next
        // open; failing loudly here would be noise on every flaky request.
        acknowledgedRef.current = null;
      });
  }, [conversationId, newestId, queryClient]);

  // Stick to the bottom for new arrivals, but never yank the viewport away
  // from someone reading history further up.
  const messageCount = thread.length;
  useLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    const nearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 200;
    if (nearBottom || messageCount === 0) el.scrollTop = el.scrollHeight;
  }, [messageCount, conversationId]);

  const loadOlder = async () => {
    const before = oldestMessageId(readMessages());
    if (before == null || loadingOlder || !hasMore) return;
    const el = scrollRef.current;
    const previousHeight = el?.scrollHeight ?? 0;
    setLoadingOlder(true);
    try {
      const page = await chatApi.messages(conversationId, { before, limit: MESSAGE_PAGE_SIZE });
      queryClient.setQueryData<ThreadMessage[]>(messagesKey, (current) =>
        mergeMessages(current ?? [], page.items),
      );
      setHasMore(page.hasMore);
      // Prepending grows the scroll height above the viewport; keep the row the
      // trainer was looking at where it was instead of jumping to the top.
      requestAnimationFrame(() => {
        if (el) el.scrollTop = el.scrollHeight - previousHeight;
      });
    } catch {
      show(t("loadOlderFailed"), "error");
    } finally {
      setLoadingOlder(false);
    }
  };

  const sendMutation = useMutation({
    mutationFn: ({ body, clientMessageId }: { body: string; clientMessageId: string }) =>
      chatApi.send(conversationId, { body, clientMessageId }),
    onMutate: ({ body, clientMessageId }) => {
      queryClient.setQueryData<ThreadMessage[]>(messagesKey, (current) => {
        const optimistic: ThreadMessage = {
          id: null,
          conversationId,
          senderId: ownUserId,
          body,
          clientMessageId,
          createdAt: new Date().toISOString(),
          deletedAt: null,
          state: "pending",
        };
        const rest = (current ?? []).filter((m) => m.clientMessageId !== clientMessageId);
        return [...rest, optimistic];
      });
    },
    onSuccess: (stored: MessageResponse) => {
      queryClient.setQueryData<ThreadMessage[]>(messagesKey, (current) =>
        mergeMessages(current ?? [], [stored]),
      );
      queryClient.invalidateQueries({ queryKey: queryKeys.chat.conversations() });
    },
    onError: (error, { clientMessageId }) => {
      queryClient.setQueryData<ThreadMessage[]>(messagesKey, (current) =>
        (current ?? []).map((m) =>
          m.clientMessageId === clientMessageId ? { ...m, state: "failed" } : m,
        ),
      );
      show(t(sendErrorKey(error)), "error");
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (messageId: number) => chatApi.deleteMessage(messageId),
    onSuccess: (_result, messageId) => {
      queryClient.setQueryData<ThreadMessage[]>(messagesKey, (current) =>
        (current ?? []).map((m) =>
          m.id === messageId ? { ...m, body: null, deletedAt: new Date().toISOString() } : m,
        ),
      );
      queryClient.invalidateQueries({ queryKey: queryKeys.chat.conversations() });
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  const retry = (clientMessageId: string) => {
    const message = readMessages().find((m) => m.clientMessageId === clientMessageId);
    // Same clientMessageId as the first attempt — the server answers a replay
    // with the stored message instead of a duplicate (§12.4).
    if (message?.body) sendMutation.mutate({ body: message.body, clientMessageId });
  };

  const discard = (clientMessageId: string) => {
    queryClient.setQueryData<ThreadMessage[]>(messagesKey, (current) =>
      (current ?? []).filter((m) => m.clientMessageId !== clientMessageId),
    );
  };

  const muteMutation = useMutation({
    mutationFn: (mutedUntil: string | null) => chatApi.mute(conversationId, mutedUntil),
    onSuccess: (_result, mutedUntil) => {
      // Patched in place rather than invalidated: nothing else about the thread
      // changed, and a refetch would reorder the list for a mute.
      queryClient.setQueryData<{ items: ConversationResponse[] }>(
        queryKeys.chat.conversations(),
        (current) =>
          current && {
            items: current.items.map((c) => (c.id === conversationId ? { ...c, mutedUntil } : c)),
          },
      );
      show(mutedUntil ? t("muted") : t("unmuted"), "success");
    },
    onError: () => show(t("muteFailed"), "error"),
  });

  const items = buildThreadItems(thread, ownUserId);
  const archived = conversation.archivedAt !== null;
  const muted = isMuted(conversation.mutedUntil);

  return (
    <div
      className="flex flex-col min-h-0 rounded-[var(--r-card)] overflow-hidden"
      style={{ background: "var(--surface)" }}
    >
      <header
        className="flex items-center gap-3 px-5 h-[66px] shrink-0"
        style={{ borderBottom: "1px solid var(--surface-container)" }}
      >
        {onBack && (
          <button onClick={onBack} aria-label={t("backToList")} style={{ color: "var(--on-surface-variant)" }}>
            <span className="material-symbols-rounded text-2xl">arrow_back</span>
          </button>
        )}
        <ChatAvatar userId={conversation.peer.userId} displayName={conversation.peer.displayName} size={40} />
        <div className="flex-1 min-w-0">
          <p className="text-[15px] font-extrabold truncate" style={{ color: "var(--on-surface)" }}>
            {conversation.peer.displayName}
          </p>
          {/* No "online / last seen" line: presence lands with I4, and the design
              rules out a status signal that isn't backed by real data. */}
          <p className="text-[11px] font-semibold truncate" style={{ color: "var(--muted)" }}>
            {conversation.peer.email}
          </p>
        </div>
        {archived && (
          <span
            className="rounded-[var(--r-sm)] px-2.5 py-1 text-[10.5px] font-extrabold"
            style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
          >
            {t("archivedBadge")}
          </span>
        )}
        <MuteMenu
          muted={muted}
          onMute={(hours) => muteMutation.mutate(muteUntil(hours))}
          onUnmute={() => muteMutation.mutate(null)}
        />
        {conversation.peer.role === "CLIENT" && (
          <Link
            href={`/admin/clients/${conversation.peer.userId}`}
            title={t("openClient")}
            aria-label={t("openClient")}
            className="w-[38px] h-[38px] rounded-xl flex items-center justify-center shrink-0"
            style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
          >
            <span className="material-symbols-rounded text-[21px]">person</span>
          </Link>
        )}
      </header>

      <div
        ref={scrollRef}
        onScroll={(e) => {
          if (e.currentTarget.scrollTop < 80) void loadOlder();
        }}
        className="flex-1 min-h-0 overflow-y-auto px-6 py-5"
      >
        {isLoading ? (
          <ThreadSkeleton />
        ) : isError ? (
          <ErrorState onRetry={refetch} />
        ) : items.length === 0 ? (
          <EmptyState
            icon="forum"
            title={t("emptyThreadTitle")}
            body={t("emptyThreadBody", { name: conversation.peer.displayName })}
          />
        ) : (
          <>
            {loadingOlder && (
              <p className="text-center text-[11px] font-semibold pb-3" style={{ color: "var(--muted)" }}>
                {t("loadingOlder")}
              </p>
            )}
            {items.map((item) =>
              item.kind === "day" ? (
                <div key={item.key} className="flex justify-center my-3">
                  <span
                    className="rounded-[10px] px-3 py-1 text-[11px] font-bold"
                    style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
                  >
                    {dayLabel(item.at, locale, t("today"), t("yesterday"))}
                  </span>
                </div>
              ) : (
                <MessageBubble
                  key={item.key}
                  message={item.message}
                  own={item.own}
                  groupStart={item.groupStart}
                  groupEnd={item.groupEnd}
                  peerName={conversation.peer.displayName}
                  peerUserId={conversation.peer.userId}
                  receiptState={receiptStateFor(
                    item.message,
                    conversation.peerLastDeliveredMessageId,
                    conversation.peerLastReadMessageId,
                  )}
                  onRetry={retry}
                  onDiscard={discard}
                  onDelete={(id) => deleteMutation.mutate(id)}
                />
              ),
            )}
          </>
        )}
      </div>

      {archived ? (
        <ArchivedComposerNotice />
      ) : (
        <ChatComposer
          onSend={(body) => sendMutation.mutate({ body, clientMessageId: newClientMessageId() })}
        />
      )}
    </div>
  );
}

/**
 * The design's thread overflow menu, back now that it has two live items —
 * mute was I5 work, and until it landed a one-item dropdown was worse than the
 * bare link it would have wrapped (see the plan §14.2).
 */
function MuteMenu({
  muted,
  onMute,
  onUnmute,
}: {
  muted: boolean;
  onMute: (hours: number | null) => void;
  onUnmute: () => void;
}) {
  const t = useTranslations("chat");
  const [open, setOpen] = useState(false);

  return (
    <div className="relative shrink-0">
      <button
        onClick={() => (muted ? onUnmute() : setOpen((o) => !o))}
        title={muted ? t("unmute") : t("mute")}
        aria-label={muted ? t("unmute") : t("mute")}
        className="w-[38px] h-[38px] rounded-xl flex items-center justify-center"
        style={{
          background: "var(--surface-container)",
          color: muted ? "var(--on-surface)" : "var(--on-surface-variant)",
        }}
      >
        <span className="material-symbols-rounded text-[21px]">
          {muted ? "notifications_off" : "notifications"}
        </span>
      </button>

      {open && !muted && (
        <>
          {/* Click-away layer: cheaper and more reliable than a document
              listener that has to be careful not to catch the opening click. */}
          <button
            className="fixed inset-0 z-10 cursor-default"
            aria-label={t("closeMenu")}
            onClick={() => setOpen(false)}
          />
          <div
            className="absolute right-0 top-11 z-20 w-[200px] rounded-[var(--r-md)] p-1.5"
            style={{ background: "var(--surface-high)", boxShadow: "0 12px 30px rgba(0,0,0,.5)" }}
          >
            {MUTE_DURATIONS_HOURS.map((hours) => (
              <button
                key={hours}
                onClick={() => {
                  onMute(hours);
                  setOpen(false);
                }}
                className="w-full text-left px-3 py-2 rounded-[10px] text-[12.5px] font-bold transition-colors hover:bg-surface-highest"
                style={{ color: "var(--on-surface)" }}
              >
                {t("muteForHours", { hours })}
              </button>
            ))}
            <button
              onClick={() => {
                onMute(null);
                setOpen(false);
              }}
              className="w-full text-left px-3 py-2 rounded-[10px] text-[12.5px] font-bold transition-colors hover:bg-surface-highest"
              style={{ color: "var(--on-surface)" }}
            >
              {t("muteUntilFurtherNotice")}
            </button>
          </div>
        </>
      )}
    </div>
  );
}

function ThreadSkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {[0, 1, 2, 3].map((i) => (
        <div
          key={i}
          className={`skeleton-pulse h-[46px] rounded-[18px] ${i % 2 === 0 ? "w-2/5" : "w-1/2 self-end"}`}
        />
      ))}
    </div>
  );
}

function dayLabel(iso: string, locale: keyof typeof DATE_LOCALES, today: string, yesterday: string): string {
  const date = new Date(iso);
  if (isToday(date)) return today;
  if (isYesterday(date)) return yesterday;
  return format(date, "yyyy. MMM d.", { locale: DATE_LOCALES[locale] });
}

/** The send failures worth naming apart: archived thread, rate limit, kill switch. */
function sendErrorKey(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status === 409) return "sendFailedArchived";
    if (error.status === 429) return "sendFailedRateLimited";
    if (error.status === 503) return "sendFailedDisabled";
  }
  return "sendFailed";
}
