"use client";

import { useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { differenceInCalendarDays, isToday } from "date-fns";
import { CountPill, Icon, TextField } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { ChatAvatar } from "./ChatAvatar";
import { filterConversations, hasMixedPeerRoles, isMuted } from "../thread";
import type { ConversationResponse } from "../types";

interface ConversationListProps {
  conversations: ConversationResponse[] | undefined;
  selectedId: number | null;
  ownUserId: number | undefined;
  onSelect: (conversationId: number) => void;
  isLoading: boolean;
  isError: boolean;
  onRetry: () => void;
}

/**
 * The left column of the chat (W8-D): a search and one row per conversation — avatar, name, the time, the preview
 * (bold when unread, "Te: …" for your own last message) and an unread `CountPill`; the selected row is `--nested` with
 * a 3 px primary bar. Archived threads fade, muted ones carry a bell-off, and a client row has an "open client" link.
 */
export function ConversationList({ conversations, selectedId, ownUserId, onSelect, isLoading, isError, onRetry }: ConversationListProps) {
  const t = useTranslations("chat");
  const common = useTranslations("common");
  const [search, setSearch] = useState("");

  const visible = conversations ? filterConversations(conversations, search) : [];
  const showRoleLabels = conversations ? hasMixedPeerRoles(conversations) : false;

  return (
    <div className="flex flex-col gap-2 p-3 min-h-0" style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }}>
      <TextField size="dense" type="search" leadingIcon="search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder={common("search")} aria-label={t("searchConversations")} />

      <div className="flex-1 min-h-0 overflow-y-auto flex flex-col gap-1">
        {isLoading ? (
          Array.from({ length: 5 }).map((_, i) => <div key={i} className="skeleton-pulse h-[64px] rounded-[var(--r-control)] shrink-0" />)
        ) : isError ? (
          <ErrorState inline onRetry={onRetry} />
        ) : visible.length === 0 ? (
          <EmptyState
            icon={search ? "search_off" : "forum"}
            title={search ? t("noSearchResultsTitle") : t("noConversationsTitle")}
            body={search ? t("noSearchResultsBody") : t("noConversationsBody")}
          />
        ) : (
          visible.map((conversation) => (
            <ConversationRow key={conversation.id} conversation={conversation} selected={conversation.id === selectedId} showRoleLabel={showRoleLabels} ownUserId={ownUserId} onSelect={() => onSelect(conversation.id)} />
          ))
        )}
      </div>
    </div>
  );
}

function ConversationRow({ conversation, selected, showRoleLabel, ownUserId, onSelect }: { conversation: ConversationResponse; selected: boolean; showRoleLabel: boolean; ownUserId: number | undefined; onSelect: () => void }) {
  const t = useTranslations("chat");
  const fmt = useFormat();
  const { peer, lastMessage, unreadCount, archivedAt } = conversation;
  const archived = archivedAt !== null;
  const unread = unreadCount > 0;
  const muted = isMuted(conversation.mutedUntil);

  const ownPrefix = lastMessage && lastMessage.senderId === ownUserId ? t("ownMessagePrefix") : "";
  // A picture with no caption still needs words in the list, and the marker stays in front of a caption so the row says what kind of message it was.
  const imageMarker = lastMessage?.attachment ? `${t("imagePreview")} ` : "";
  const preview = lastMessage
    ? lastMessage.deletedAt
      ? `${ownPrefix}${t("deletedMessage")}`
      : `${ownPrefix}${imageMarker}${lastMessage.body ?? ""}`.trimEnd()
    : t("noMessagesYet");

  // Today → the clock, this week → the weekday, older → the date.
  const when = (iso: string) => {
    const date = new Date(iso);
    const now = new Date();
    if (isToday(date)) return fmt.time(date);
    if (differenceInCalendarDays(now, date) < 7) return fmt.weekdayShort(date);
    return fmt.shortDate(date);
  };

  return (
    <div className="group relative flex items-center shrink-0" style={{ borderRadius: "var(--r-control)", background: selected ? "var(--nested)" : "transparent", opacity: archived ? 0.55 : 1 }}>
      {selected && <span aria-hidden className="absolute left-0 top-2 bottom-2" style={{ width: 3, borderRadius: 2, background: "var(--primary)" }} />}
      <button type="button" onClick={onSelect} aria-current={selected ? "true" : undefined} className="lifey-button flex flex-1 min-w-0 items-center gap-3 px-3 py-2.5 text-left">
        <ChatAvatar userId={peer.userId} displayName={peer.displayName} muted={archived} />
        <span className="flex-1 min-w-0">
          <span className="flex items-center gap-1.5">
            <span className="truncate" style={{ fontSize: 14, fontWeight: unread ? 800 : 700 }}>{peer.displayName}</span>
            {showRoleLabel && (
              <span className="whitespace-nowrap shrink-0" style={{ fontSize: 11, fontWeight: 700, color: "var(--text-3)" }}>
                {peer.role === "TRAINER" ? t("peerRoleTrainer") : t("peerRoleClient")}
              </span>
            )}
          </span>
          <span className="block truncate type-body-s" style={{ color: unread ? "var(--text)" : "var(--text-2)", fontWeight: unread ? 700 : 400, fontStyle: lastMessage?.deletedAt ? "italic" : undefined }}>
            {preview}
          </span>
        </span>
        <span className="flex flex-col items-end gap-1.5 shrink-0">
          {muted && !archived && <Icon name="notifications_off" size={16} color="var(--text-3)" label={t("mutedRow")} />}
          {archived ? (
            <span className="px-2 type-body-s" style={{ borderRadius: 6, background: "var(--control)", fontWeight: 700 }}>{t("archivedBadge")}</span>
          ) : (
            lastMessage && <span className="type-body-s" style={{ color: unread ? "var(--primary)" : "var(--text-3)", fontWeight: 600 }}>{when(lastMessage.createdAt)}</span>
          )}
          {unread && (
            <span aria-label={t("unreadCount", { count: unreadCount })}>
              <CountPill count={unreadCount} />
            </span>
          )}
        </span>
      </button>
      {peer.role === "CLIENT" && (
        <Link
          href={`/admin/clients/${peer.userId}`}
          title={t("openClient")}
          aria-label={t("openClient")}
          className="mr-2 inline-flex h-8 w-8 items-center justify-center shrink-0 opacity-0 transition-opacity group-hover:opacity-100 focus:opacity-100"
          style={{ borderRadius: 10, background: "var(--control)", color: "var(--text-2)" }}
        >
          <Icon name="person" size={18} />
        </Link>
      )}
    </div>
  );
}
