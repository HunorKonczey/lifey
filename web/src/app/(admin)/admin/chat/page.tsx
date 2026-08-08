"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { useSessionStore } from "@/features/auth/store";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { EmptyState } from "@/components/status/EmptyState";
import { ConversationList } from "@/features/chat/components/ConversationList";
import { ChatThread } from "@/features/chat/components/ChatThread";
import { useConversations, usePresence, useUnreadDocumentTitle } from "@/features/chat/hooks";
import { totalUnread } from "@/features/chat/thread";

/**
 * The trainer's desktop alternative to the mobile chat (docs/chat/40-trainer-chat-plan.md I3).
 * Two columns above the tablet breakpoint; below it the thread replaces the
 * list and a back button returns — the mobile behaviour, not a second pattern.
 */
export default function AdminChatPage() {
  const t = useTranslations("chat");
  const admin = useTranslations("admin");
  const router = useRouter();
  const searchParams = useSearchParams();
  const user = useSessionStore((s) => s.user);
  const twoColumn = useMediaQuery("(min-width: 1024px)");

  const { data: conversations, isLoading, isError, refetch } = useConversations();
  useUnreadDocumentTitle(conversations ? totalUnread(conversations) : 0);

  // The open thread lives in "?c=<id>" rather than in component state: that is
  // the handover the client detail page uses, and it survives a reload.
  const selectedParam = searchParams.get("c");
  const selectedId = selectedParam ? Number(selectedParam) : null;

  // The open thread doubles as the presence signal: while it is on screen the
  // server treats messages in it as seen and skips the push (§5.1).
  usePresence(selectedId);

  const select = (conversationId: number) => router.replace(`/admin/chat?c=${conversationId}`);
  const back = () => router.replace("/admin/chat");

  const selected = conversations?.find((c) => c.id === selectedId) ?? null;
  // A ?c= pointing at a thread that isn't in the list (revoked, or another
  // account's) resolves to the empty right-hand pane rather than an error.
  const showList = twoColumn || selected === null;
  const showThread = twoColumn || selected !== null;

  return (
    <div className="flex flex-col gap-3.5 h-[calc(100vh-28px)]">
      <div
        className="flex items-center gap-3 rounded-[var(--r-card)] h-[62px] px-5 shrink-0"
        style={{ background: "var(--surface-high)" }}
      >
        <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
          {t("title")}
        </p>
        <span
          className="rounded-[9px] px-2.5 py-1 text-[10.5px] font-extrabold tracking-wide"
          style={{
            border: "1px solid color-mix(in srgb, var(--tertiary) 50%, transparent)",
            background: "color-mix(in srgb, var(--tertiary) 14%, transparent)",
            color: "var(--tertiary)",
          }}
        >
          {admin("chip")}
        </span>
      </div>

      <div
        className="flex-1 min-h-0 grid gap-3.5"
        style={{ gridTemplateColumns: twoColumn ? "340px minmax(0, 1fr)" : "minmax(0, 1fr)" }}
      >
        {showList && (
          <ConversationList
            conversations={conversations}
            selectedId={selectedId}
            ownUserId={user?.id}
            onSelect={select}
            isLoading={isLoading}
            isError={isError}
            onRetry={refetch}
          />
        )}

        {showThread &&
          (selected && user ? (
            <ChatThread
              key={selected.id}
              conversation={selected}
              ownUserId={user.id}
              onBack={twoColumn ? undefined : back}
            />
          ) : (
            <div
              className="flex items-center justify-center rounded-[var(--r-card)] min-h-0"
              style={{ background: "var(--surface)" }}
            >
              <EmptyState icon="forum" title={t("noSelectionTitle")} body={t("noSelectionBody")} />
            </div>
          ))}
      </div>
    </div>
  );
}
