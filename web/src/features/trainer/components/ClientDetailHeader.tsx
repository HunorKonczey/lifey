"use client";

import Link from "next/link";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button, ConfirmModal, Icon, Menu, Tabs } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import { chatApi } from "@/features/chat/api";
import { DRAFT_PARAM, greetingName } from "@/features/chat/draft";
import { invalidationMap } from "@/lib/api/queryKeys";
import { trainerApi } from "../api";
import { complianceFor } from "../compliance";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";
import type { TrainerClientResponse } from "../types";

export type ClientTab = "overview" | "statistics" | "steps" | "nutrition" | "workouts" | "schedule";

export const CLIENT_TABS: ClientTab[] = ["overview", "statistics", "steps", "nutrition", "workouts", "schedule"];

interface ClientDetailHeaderProps {
  client: TrainerClientResponse;
  tab: ClientTab;
  onTabChange: (tab: ClientTab) => void;
  onScheduleWorkout: () => void;
}

/**
 * The client page's header card (W7-B): crumb back to the list, avatar, name, "kliens aug. 17. óta", and the actions
 * in a row that wraps under the name when narrow — Üzenet, Ütemezés, "⋯" (remove the client). An inactive client gets
 * a heart band inside the card with a reminder button (W7-D). The six tabs sit under it, the active one kept in view.
 */
export function ClientDetailHeader({ client, tab, onTabChange, onScheduleWorkout }: ClientDetailHeaderProps) {
  const t = useTranslations("admin.clientDetail");
  const dash = useTranslations("admin.dashboard");
  const chat = useTranslations("chat");
  const nav = useTranslations("admin.nav");
  const fmt = useFormat();
  const router = useRouter();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const menuRef = useRef<HTMLButtonElement>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [confirmingRemove, setConfirmingRemove] = useState(false);

  const name = clientDisplayName(client);
  const flags = complianceFor(client);

  // Lazy-create keyed on the client's user id: this page holds `clientId`, not the trainer_clients row id that
  // POST /chat/conversations wants.
  const openChat = useMutation({
    mutationFn: (draft?: string) => chatApi.openConversationWithUser(client.clientId).then((c) => ({ c, draft })),
    onSuccess: ({ c, draft }) =>
      router.push(`/admin/chat?c=${c.id}${draft ? `&${DRAFT_PARAM}=${encodeURIComponent(draft)}` : ""}`),
    onError: () => show(chat("openConversationFailed"), "error"),
  });

  const revoke = useMutation({
    mutationFn: () => trainerApi.revokeClient(client.clientId),
    onSuccess: () => {
      invalidationMap.trainerClient.forEach((key) => queryClient.invalidateQueries({ queryKey: key }));
      show(dash("relationshipEnded"), "success");
      router.push("/admin");
    },
    onError: () => show(dash("relationshipEndFailed"), "error"),
  });

  const since = fmt.mediumDate(new Date(client.activeSince));
  const lastSeen = client.lastActivityAt ? fmt.mediumDate(new Date(client.lastActivityAt)) : null;

  return (
    <div className="flex flex-col gap-5">
      <section
        aria-label={name}
        className="flex flex-col gap-4 p-5"
        style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }}
      >
        <Link href="/admin" className="inline-flex items-center gap-1 type-body-s w-fit" style={{ color: "var(--text-2)", fontWeight: 600 }}>
          <Icon name="chevron_left" size={18} />
          {nav("clients")}
        </Link>

        <div className="flex flex-wrap items-center gap-x-4 gap-y-3">
          <ClientAvatar clientId={client.clientId} email={client.clientEmail} size={56} />
          <div className="flex-1 min-w-[180px]">
            <h2 className="truncate" style={{ fontSize: 26, lineHeight: 1.15, fontWeight: 800, letterSpacing: "-0.02em" }}>{name}</h2>
            <p className="type-body-s truncate" style={{ color: "var(--text-2)" }}>
              {client.clientEmail} · {t("clientSince", { date: since })}
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Button variant="secondary" onClick={() => openChat.mutate(undefined)} disabled={openChat.isPending}>
              <Icon name="chat_bubble" size={18} />
              {chat("messageCta")}
            </Button>
            <Button variant="secondary" onClick={onScheduleWorkout}>
              <Icon name="event" size={18} />
              {t("scheduleAction")}
            </Button>
            <button
              ref={menuRef}
              type="button"
              aria-label={t("moreAria")}
              aria-haspopup="menu"
              aria-expanded={menuOpen}
              onClick={() => setMenuOpen(true)}
              className="lifey-button inline-flex items-center justify-center h-11 md:h-10 w-11 md:w-10"
              style={{ borderRadius: "var(--r-control)", background: "var(--nested)", boxShadow: "inset 0 0 0 1px var(--hairline)" }}
            >
              <Icon name="more_horiz" size={22} />
            </button>
            <Menu
              open={menuOpen}
              onClose={() => setMenuOpen(false)}
              anchorRef={menuRef}
              items={[{ label: t("removeClient"), icon: "link_off", destructive: true, onSelect: () => setConfirmingRemove(true) }]}
            />
          </div>
        </div>

        {flags.inactive && (
          <div
            role="status"
            data-testid="inactive-band"
            className="flex flex-wrap items-center gap-3 px-4 py-3"
            style={{ borderRadius: "var(--r-control)", background: "color-mix(in srgb, var(--heart) 14%, transparent)" }}
          >
            <Icon name="notifications_active" size={22} fill={1} color="var(--heart)" />
            <p className="type-body flex-1 min-w-[200px]" style={{ fontWeight: 600 }}>
              {lastSeen ? t("inactiveBand", { count: flags.daysSinceLastLog, date: lastSeen }) : t("inactiveBandNever", { count: flags.daysSinceLastLog })}
              {flags.hasMissedWorkouts && ` ${t("inactiveBandMissed", { count: flags.missedWorkouts })}`}
            </p>
            <Button
              variant="secondary"
              disabled={openChat.isPending}
              onClick={() => openChat.mutate(dash("draftInactive", { name: greetingName(client.clientFirstName, name) }))}
            >
              {t("sendReminder")}
            </Button>
          </div>
        )}
      </section>

      <Tabs<ClientTab>
        aria-label={t("tabsAria")}
        value={tab}
        onChange={onTabChange}
        items={CLIENT_TABS.map((key) => ({ value: key, label: t(`tabs.${key}`) }))}
      />

      <ConfirmModal
        open={confirmingRemove}
        onClose={() => setConfirmingRemove(false)}
        onConfirm={() => {
          setConfirmingRemove(false);
          revoke.mutate();
        }}
        title={dash("endRelationshipConfirmTitle")}
        body={dash("endRelationshipConfirmBody", { name })}
        icon="link_off"
        cancelLabel={dash("cancel")}
        confirmLabel={dash("endRelationshipConfirm")}
      />
    </div>
  );
}
