"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import type { TrainerInviteResponse } from "../types";

const MAX_ROWS = 4;

/** "N függő meghívó" (W7-A side card): the e-mails still waiting, how long ago each was sent, a link to manage them. Hidden when there are none. */
export function PendingInvitesCard({ invites }: { invites: TrainerInviteResponse[] }) {
  const t = useTranslations("admin.dashboard");
  const fmt = useFormat();
  if (invites.length === 0) return null;
  const now = new Date();
  const sorted = [...invites].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  return (
    <aside className="flex flex-col gap-3 p-5" style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }} data-testid="pending-invites">
      <div className="flex items-center gap-2" style={{ fontWeight: 800, fontSize: 16 }}>
        <Icon name="mail" size={20} color="var(--text-2)" />
        {t("pendingTitle", { count: invites.length })}
      </div>
      <ul className="flex flex-col gap-2">
        {sorted.slice(0, MAX_ROWS).map((i) => (
          <li key={i.id} className="flex items-baseline justify-between gap-3 type-body-s">
            <span className="truncate" style={{ fontWeight: 600 }}>{i.clientEmail}</span>
            <span className="shrink-0" style={{ color: "var(--text-3)" }}>{fmt.relative(new Date(i.createdAt), now)}</span>
          </li>
        ))}
      </ul>
      {invites.length > MAX_ROWS && <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("pendingMore", { count: invites.length - MAX_ROWS })}</p>}
      <Link href="/admin/invites" className="type-body-s" style={{ color: "var(--primary)", fontWeight: 700 }}>
        {t("pendingManage")} →
      </Link>
    </aside>
  );
}
