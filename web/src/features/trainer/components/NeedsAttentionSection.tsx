"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { byLeastActiveFirst, complianceFor } from "../compliance";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import type { TrainerClientResponse } from "../types";

interface NeedsAttentionSectionProps {
  clients: TrainerClientResponse[];
}

/** Spotlight for flagged clients (docs/29) — additive to the grid below, not a filter:
 *  flagged clients still appear in their normal place in the full list. */
export function NeedsAttentionSection({ clients }: NeedsAttentionSectionProps) {
  const t = useTranslations("admin.dashboard");
  const now = new Date();
  const flagged = clients.filter((c) => complianceFor(c, now).needsAttention).sort((a, b) => byLeastActiveFirst(a, b, now));

  if (flagged.length === 0) return null;

  return (
    <div className="rounded-[var(--r-lg)] p-4" style={{ background: "var(--error-container)" }}>
      <div className="flex items-center gap-2 mb-3 px-1">
        <span className="material-symbols-rounded text-lg" style={{ color: "var(--error)" }}>
          warning
        </span>
        <p className="text-[13px] font-extrabold" style={{ color: "var(--error)" }}>
          {t("needsAttentionTitle", { count: flagged.length })}
        </p>
      </div>
      <div className="flex flex-col gap-1.5">
        {flagged.map((client) => {
          const flags = complianceFor(client, now);
          return (
            <Link
              key={client.clientId}
              href={`/admin/clients/${client.clientId}`}
              className="flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors hover:bg-black/10"
              style={{ background: "var(--surface)" }}
            >
              <ClientAvatar clientId={client.clientId} email={client.clientEmail} size={34} />
              <p className="text-[13.5px] font-extrabold flex-1 min-w-0 truncate" style={{ color: "var(--on-surface)" }}>
                {nameFor(client.clientEmail)}
              </p>
              <div className="flex flex-wrap items-center justify-end gap-1.5">
                {flags.inactive && (
                  <ReasonChip label={t("inactiveBadge", { count: flags.daysSinceLastLog })} />
                )}
                {flags.hasMissedWorkouts && (
                  <ReasonChip label={t("missedWorkoutsBadge", { count: flags.missedWorkouts })} />
                )}
                {flags.weightStale && (
                  <ReasonChip label={t("weightStaleBadge", { count: flags.daysSinceWeight })} />
                )}
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

function ReasonChip({ label }: { label: string }) {
  return (
    <span
      className="rounded-[var(--r-pill)] text-[10.5px] font-bold px-2 py-1 whitespace-nowrap"
      style={{ background: "var(--error-container)", color: "var(--error)" }}
    >
      {label}
    </span>
  );
}
