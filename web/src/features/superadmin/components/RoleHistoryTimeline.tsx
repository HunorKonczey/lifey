"use client";

import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";
import { useFormat } from "@/lib/i18n/format";
import { auditTransition, personLabel } from "../userRoles";

export interface TimelineEntry {
  id: number;
  createdAt: string;
  role: string;
  action: "GRANT" | "REVOKE";
  actorName: string | null;
  actorEmail: string | null;
  /** Set in the global feed (whose role changed); the per-user drawer leaves it out. */
  targetName?: string | null;
  targetEmail?: string | null;
}

const ICON_COLOR = { grant: "var(--primary)", revoke: "var(--heart)", neutral: "var(--text-2)" } as const;

/**
 * Who changed whose role, when — an icon timeline, newest first (W9-G): a primary check for a grant, a heart
 * person-remove for a revoke, a neutral shield for any other role; "Szabó Bence: Kliens → Edző" and "jóváhagyta:
 * Admin · aug. 12.", the actor named by profile name or, failing that, e-mail.
 */
export function RoleHistoryTimeline({ entries }: { entries: TimelineEntry[] }) {
  const t = useTranslations("superadmin");
  const fmt = useFormat();

  return (
    <ol className="flex flex-col" data-testid="role-timeline">
      {entries.map((entry, i) => {
        const tr = auditTransition(entry);
        const target = personLabel(entry.targetName, entry.targetEmail);
        const actor = personLabel(entry.actorName, entry.actorEmail) ?? t("unknownActor");
        const change = tr.from && tr.to ? `${t(`role.${tr.from}`)} → ${t(`role.${tr.to}`)}` : t(entry.action === "GRANT" ? "roleGranted" : "roleRevoked");
        return (
          <li key={entry.id} className="relative flex gap-3 pb-5" data-testid="role-timeline-entry">
            {i < entries.length - 1 && <span aria-hidden className="absolute left-[15px] top-8 bottom-0 w-px" style={{ background: "var(--hairline)" }} />}
            <span
              className="z-[1] flex h-8 w-8 shrink-0 items-center justify-center rounded-full"
              style={{ background: `color-mix(in srgb, ${ICON_COLOR[tr.tone]} var(--chip-tint), transparent)` }}
            >
              <Icon name={tr.icon} size={18} color={ICON_COLOR[tr.tone]} />
            </span>
            <div className="min-w-0">
              <p className="type-body" style={{ fontWeight: 700 }}>{target ? `${target}: ${change}` : change}</p>
              <p className="type-body-s" style={{ color: "var(--text-3)" }}>
                {t(entry.action === "GRANT" ? "approvedBy" : "revokedBy", { actor })} · {fmt.date(entry.createdAt, "dayYear")}
              </p>
            </div>
          </li>
        );
      })}
    </ol>
  );
}
