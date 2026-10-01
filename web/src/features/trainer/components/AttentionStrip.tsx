"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";
import { chatDraftHref, greetingName } from "@/features/chat/draft";
import type { ConversationResponse } from "@/features/chat/types";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";
import { pickForStrip, type AttentionItem, type AttentionKind } from "../clientSignals";
import type { TrainerClientResponse } from "../types";

const TONE: Record<AttentionKind, { color: string; icon: string }> = {
  inactive: { color: "var(--heart)", icon: "notifications_active" },
  unread: { color: "var(--primary)", icon: "chat" },
  missed: { color: "var(--heart)", icon: "event_busy" },
  record: { color: "var(--metric-carbs)", icon: "emoji_events" },
};

const MAX_CARDS = 3;

/**
 * "Ma figyelmet igényel" (W7-A): up to three cards for what the trainer should look at today — an inactive client, an
 * unread message, a missed workout or a new record — each with one button. The messaging ones open that client's
 * conversation with a draft already in the composer (nothing is sent); the strip is absent when nothing needs the eye.
 */
export function AttentionStrip({ items, clients, conversations, compact = false }: { items: AttentionItem[]; clients: TrainerClientResponse[]; conversations: ConversationResponse[] | undefined; compact?: boolean }) {
  const t = useTranslations("admin.dashboard");
  if (items.length === 0) return null;
  const byId = new Map(clients.map((c) => [c.clientId, c]));
  const shown = pickForStrip(items, compact ? 1 : MAX_CARDS);

  return (
    <section aria-labelledby="attention-title" data-testid="attention-strip" className="flex flex-col gap-3">
      <h2 id="attention-title" className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 800, letterSpacing: "0.06em", textTransform: "uppercase" }}>
        {t("attentionTitle", { count: items.length })}
      </h2>
      <div className={compact ? "flex flex-col gap-2" : "grid grid-cols-1 md:grid-cols-3 gap-3"}>
        {shown.map((item) => {
          const client = byId.get(item.clientId);
          if (!client) return null;
          const name = clientDisplayName(client);
          const first = greetingName(client.clientFirstName, name);
          const tone = TONE[item.kind];
          const conversation = conversations?.find((c) => c.peer.userId === client.clientId);
          const chat = (draftKey: string) => chatDraftHref(conversations, client.clientId, t(draftKey, { name: first })) ?? "/admin/chat";
          const cta =
            item.kind === "inactive"
              ? { label: t("ctaMessage"), href: chat("draftInactive") }
              : item.kind === "unread"
                ? { label: t("ctaReply"), href: conversation ? `/admin/chat?c=${conversation.id}` : "/admin/chat" }
                : item.kind === "missed"
                  ? { label: t("ctaSchedule"), href: `/admin/clients/${client.clientId}?tab=schedule` }
                  : { label: t("ctaCongratulate"), href: chat("draftRecord") };
          const body =
            item.kind === "inactive"
              ? t("attentionInactiveBody", { count: item.count })
              : item.kind === "unread"
                ? item.preview
                  ? `“${item.preview}”`
                  : t("attentionUnreadBody")
                : item.kind === "missed"
                  ? t("attentionMissedBody", { count: item.count })
                  : t("attentionRecordBody", { count: item.count });
          const title =
            item.kind === "inactive"
              ? t("attentionInactive", { name, count: item.count })
              : item.kind === "unread"
                ? t("attentionUnread", { name, count: item.count })
                : item.kind === "missed"
                  ? t("attentionMissed", { name, count: item.count })
                  : t("attentionRecord", { name });
          return (
            <article
              key={`${item.kind}-${item.clientId}`}
              className="flex flex-col gap-3 p-4"
              style={{
                borderRadius: "var(--r-card)",
                background: "var(--card)",
                boxShadow: `inset 0 0 0 1.5px color-mix(in srgb, ${tone.color} 45%, transparent), var(--e1)`,
              }}
            >
              <div className="flex items-start gap-3">
                <span
                  className="inline-flex items-center justify-center shrink-0"
                  style={{ width: 36, height: 36, borderRadius: 12, background: `color-mix(in srgb, ${tone.color} 16%, transparent)` }}
                >
                  <Icon name={tone.icon} size={20} fill={1} color={tone.color} />
                </span>
                <div className="min-w-0">
                  <div className="truncate" style={{ fontWeight: 800, fontSize: 15 }}>{title}</div>
                  <div className="type-body-s line-clamp-2" style={{ color: "var(--text-2)" }}>{body}</div>
                </div>
              </div>
              <div className="flex items-center justify-between gap-2">
                <ClientAvatar clientId={client.clientId} email={client.clientEmail} size={28} />
                <Link href={cta.href} className="lifey-button inline-flex items-center h-10 px-4 type-button" style={{ borderRadius: "var(--r-control)", background: "var(--primary-tint)", color: "var(--on-primary-tint)" }}>
                  {cta.label}
                </Link>
              </div>
            </article>
          );
        })}
      </div>
    </section>
  );
}
