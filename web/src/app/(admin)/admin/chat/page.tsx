"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { useSessionStore } from "@/features/auth/store";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { Drawer } from "@/components/ds";
import { EmptyState } from "@/components/status/EmptyState";
import { ConversationList } from "@/features/chat/components/ConversationList";
import { ChatThread } from "@/features/chat/components/ChatThread";
import { ClientContextPanel } from "@/features/chat/components/ClientContextPanel";
import { useConversations, usePresence, useUnreadDocumentTitle } from "@/features/chat/hooks";
import { totalUnread } from "@/features/chat/thread";
import { DRAFT_PARAM } from "@/features/chat/draft";

/**
 * The trainer chat (W8-D): conversations | the thread | the client's numbers, `320 | 1fr | 300` from 1280 px. From 1024
 * the context panel is a drawer behind the thread's info button; below that the thread replaces the list (a back arrow
 * returns) and the info button opens the same panel as a sheet — one column, as on the phone.
 */
export default function AdminChatPage() {
  const t = useTranslations("chat");
  const router = useRouter();
  const searchParams = useSearchParams();
  const user = useSessionStore((s) => s.user);
  const twoColumn = useMediaQuery("(min-width: 1024px)");
  const threeColumn = useMediaQuery("(min-width: 1280px)");
  const [infoOpen, setInfoOpen] = useState(false);

  const { data: conversations, isLoading, isError, refetch } = useConversations();
  useUnreadDocumentTitle(conversations ? totalUnread(conversations) : 0);

  // The open thread lives in "?c=<id>" rather than in component state: that is the handover the client detail page uses, and it survives a reload.
  const selectedParam = searchParams.get("c");
  const selectedId = selectedParam ? Number(selectedParam) : null;
  // "?draft=" leaves a message waiting in the composer (the attention strip's CTAs); picking another thread drops it.
  const draft = searchParams.get(DRAFT_PARAM) ?? undefined;

  // The open thread doubles as the presence signal: while it is on screen the server treats messages in it as seen and skips the push (§5.1).
  usePresence(selectedId);

  const select = (conversationId: number) => router.replace(`/admin/chat?c=${conversationId}`);
  const back = () => router.replace("/admin/chat");

  const selected = conversations?.find((c) => c.id === selectedId) ?? null;
  // A ?c= pointing at a thread that isn't in the list (revoked, or another account's) resolves to the empty right-hand pane rather than an error.
  const showList = twoColumn || selected === null;
  const showThread = twoColumn || selected !== null;
  const isClientPeer = selected?.peer.role === "CLIENT";
  const inlinePanel = threeColumn && isClientPeer;
  const columns = twoColumn ? (inlinePanel ? "320px minmax(0, 1fr) 300px" : "320px minmax(0, 1fr)") : "minmax(0, 1fr)";

  return (
    <div className="grid gap-4 h-[calc(100dvh-7rem)] min-h-[480px]" style={{ gridTemplateColumns: columns }}>
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
            initialDraft={draft}
            onInfo={isClientPeer && !inlinePanel ? () => setInfoOpen(true) : undefined}
          />
        ) : (
          <div className="flex items-center justify-center min-h-0" style={{ borderRadius: "var(--r-card)", background: "var(--card)" }}>
            <EmptyState icon="forum" title={t("noSelectionTitle")} body={t("noSelectionBody")} />
          </div>
        ))}

      {inlinePanel && selected && <ClientContextPanel clientUserId={selected.peer.userId} displayName={selected.peer.displayName} />}

      {infoOpen && selected && isClientPeer && (
        <Drawer open onClose={() => setInfoOpen(false)} width={480} title={t("contextTitleShort", { name: selected.peer.displayName })}>
          <ClientContextPanel clientUserId={selected.peer.userId} displayName={selected.peer.displayName} bare />
        </Drawer>
      )}
    </div>
  );
}
