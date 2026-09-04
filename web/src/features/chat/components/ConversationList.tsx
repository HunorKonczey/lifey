"use client";

import { useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { differenceInCalendarDays, format, isToday } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { useLocale } from "@/lib/hooks/useLocale";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { ChatAvatar } from "./ChatAvatar";
import { filterConversations, hasMixedPeerRoles, isMuted, unreadBadgeLabel } from "../thread";
import type { ConversationResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

/** Today → clock, this week → weekday, older → date. Same ladder as the design's list column. */
function formatActivity(iso: string, locale: keyof typeof DATE_LOCALES): string {
  const date = new Date(iso);
  const dateLocale = DATE_LOCALES[locale];
  if (isToday(date)) return format(date, "H:mm", { locale: dateLocale });
  if (differenceInCalendarDays(new Date(), date) < 7) return format(date, "EEEE", { locale: dateLocale });
  return format(date, "yyyy. MMM d.", { locale: dateLocale });
}

interface ConversationListProps {
  conversations: ConversationResponse[] | undefined;
  selectedId: number | null;
  ownUserId: number | undefined;
  onSelect: (conversationId: number) => void;
  isLoading: boolean;
  isError: boolean;
  onRetry: () => void;
}

export function ConversationList({
  conversations,
  selectedId,
  ownUserId,
  onSelect,
  isLoading,
  isError,
  onRetry,
}: ConversationListProps) {
  const t = useTranslations("chat");
  const common = useTranslations("common");
  const locale = useLocale((s) => s.locale);
  const [search, setSearch] = useState("");

  const visible = conversations ? filterConversations(conversations, search) : [];
  const showRoleLabels = conversations ? hasMixedPeerRoles(conversations) : false;

  return (
    <div
      className="flex flex-col gap-1.5 rounded-[var(--r-card)] p-3.5 min-h-0"
      style={{ background: "var(--surface)" }}
    >
      {/* Ringed on the wrapper, not the bare input: the input is exactly as tall
          as its text, so its own focus ring would hug the letters (see the
          [data-ring-frame] rule in globals.css). */}
      <label
        data-ring-frame
        className="flex items-center gap-2.5 rounded-[var(--r-md)] px-3.5 py-2.5 mb-1 shrink-0"
        style={{ background: "var(--surface-container)" }}
      >
        <span className="material-symbols-rounded text-[19px]" style={{ color: "var(--on-surface-variant)" }}>
          search
        </span>
        <input
          type="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={common("search")}
          aria-label={t("searchConversations")}
          className="flex-1 min-w-0 bg-transparent text-[13px] font-medium outline-none"
          style={{ color: "var(--on-surface)" }}
        />
      </label>

      <div className="flex-1 min-h-0 overflow-y-auto flex flex-col gap-1.5">
        {isLoading ? (
          Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="skeleton-pulse h-[66px] rounded-[var(--r-md)] shrink-0" />
          ))
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
            <ConversationRow
              key={conversation.id}
              conversation={conversation}
              selected={conversation.id === selectedId}
              showRoleLabel={showRoleLabels}
              locale={locale}
              ownUserId={ownUserId}
              onSelect={() => onSelect(conversation.id)}
            />
          ))
        )}
      </div>
    </div>
  );
}

interface ConversationRowProps {
  conversation: ConversationResponse;
  selected: boolean;
  showRoleLabel: boolean;
  locale: keyof typeof DATE_LOCALES;
  ownUserId: number | undefined;
  onSelect: () => void;
}

function ConversationRow({
  conversation,
  selected,
  showRoleLabel,
  locale,
  ownUserId,
  onSelect,
}: ConversationRowProps) {
  const t = useTranslations("chat");
  const { peer, lastMessage, unreadCount, archivedAt } = conversation;
  const archived = archivedAt !== null;
  const unread = unreadCount > 0;
  const muted = isMuted(conversation.mutedUntil);

  const ownPrefix = lastMessage && lastMessage.senderId === ownUserId ? t("ownMessagePrefix") : "";
  // A picture with no caption still needs words in the list, and the marker
  // stays in front of a caption so the row says what kind of message it was.
  const imageMarker = lastMessage?.attachment ? `${t("imagePreview")} ` : "";
  const preview = lastMessage
    ? lastMessage.deletedAt
      ? `${ownPrefix}${t("deletedMessage")}`
      : `${ownPrefix}${imageMarker}${lastMessage.body ?? ""}`.trimEnd()
    : t("noMessagesYet");

  return (
    <div
      className="group relative flex items-center gap-2.5 rounded-[var(--r-md)] transition-colors shrink-0"
      style={{
        background: selected
          ? "color-mix(in srgb, var(--primary) 12%, transparent)"
          : "transparent",
        border: selected
          ? "1px solid color-mix(in srgb, var(--primary) 35%, transparent)"
          : "1px solid transparent",
        opacity: archived ? 0.55 : 1,
      }}
    >
      <button
        onClick={onSelect}
        aria-current={selected ? "true" : undefined}
        className="flex flex-1 min-w-0 items-center gap-2.5 px-3 py-2.5 text-left rounded-[var(--r-md)] transition-colors hover:bg-surface-container"
      >
        <ChatAvatar userId={peer.userId} displayName={peer.displayName} muted={archived} />
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5">
            <p className="text-[13.5px] font-extrabold truncate" style={{ color: "var(--on-surface)" }}>
              {peer.displayName}
            </p>
            {showRoleLabel && (
              <span
                className="text-[10px] font-bold whitespace-nowrap shrink-0"
                style={{ color: "var(--muted)" }}
              >
                {peer.role === "TRAINER" ? t("peerRoleTrainer") : t("peerRoleClient")}
              </span>
            )}
          </div>
          <p
            className="text-xs truncate mt-0.5"
            style={{
              color: unread ? "var(--on-surface)" : "var(--on-surface-variant)",
              fontWeight: unread ? 600 : 500,
              fontStyle: lastMessage?.deletedAt ? "italic" : undefined,
            }}
          >
            {preview}
          </p>
        </div>
        <div className="flex flex-col items-end gap-1.5 shrink-0">
          {muted && !archived && (
            <span
              className="material-symbols-rounded text-[16px]"
              title={t("mutedRow")}
              aria-label={t("mutedRow")}
              style={{ color: "var(--muted)" }}
            >
              notifications_off
            </span>
          )}
          {archived ? (
            <span
              className="rounded-[var(--r-sm)] px-2 py-0.5 text-[10px] font-extrabold"
              style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
            >
              {t("archivedBadge")}
            </span>
          ) : (
            lastMessage && (
              <span
                className="text-[10.5px] font-bold"
                style={{ color: unread ? "var(--primary)" : "var(--muted)" }}
              >
                {formatActivity(lastMessage.createdAt, locale)}
              </span>
            )
          )}
          {unread && (
            <span
              className="min-w-[18px] h-[18px] rounded-[9px] px-1.5 flex items-center justify-center text-[10px] font-extrabold"
              style={{ background: "var(--primary)", color: "var(--bg)" }}
              aria-label={t("unreadCount", { count: unreadCount })}
            >
              {unreadBadgeLabel(unreadCount)}
            </span>
          )}
        </div>
      </button>

      {/* The design's row overflow menu holds "mute" too, but muting is I5 work
          (chat_participants.muted_until is still unwritten) — a menu whose only
          live item is this link is worse than the link itself. */}
      {peer.role === "CLIENT" && (
        <Link
          href={`/admin/clients/${peer.userId}`}
          title={t("openClient")}
          aria-label={t("openClient")}
          className="mr-2 w-[30px] h-[30px] rounded-[10px] flex items-center justify-center shrink-0 opacity-0 transition-opacity group-hover:opacity-100 focus:opacity-100"
          style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
        >
          <span className="material-symbols-rounded text-[18px]">person</span>
        </Link>
      )}
    </div>
  );
}
