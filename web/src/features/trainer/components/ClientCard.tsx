"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Button, ConfirmModal, DeltaChip, Icon, Menu, Modal } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { lastActivity, weightChange, type WeekSummary } from "../clientSignals";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";
import type { TrainerClientResponse } from "../types";

export interface ClientCardProps {
  client: TrainerClientResponse;
  /** This client's training week from the calendar feed; null while it loads or when it failed. */
  week: WeekSummary | null;
  onRevoke: (clientId: number) => void;
  revoking?: boolean;
  /** 66 §4.1 — the seat-limit archiving flow: an inline "Archive" next to the always-available "End relationship". */
  overLimit?: boolean;
}

/** "Last activity" line text and whether it is the inactive (heart) case. */
export function useLastActivityLabel() {
  const t = useTranslations("admin.dashboard");
  return (client: TrainerClientResponse, now: Date = new Date()) => {
    const a = lastActivity(client, now);
    if (a.kind === "none") return { text: t("lastActivityNone"), alert: false };
    if (a.kind === "today") return { text: t("lastActivityToday"), alert: false };
    if (a.kind === "yesterday") return { text: t("lastActivityYesterday"), alert: false };
    return { text: t("inactiveBadge", { count: a.days }), alert: a.days >= 3 };
  };
}

/** One dot per scheduled session this week: done green, missed heart, still to come an empty ring. */
export function WeekDots({ week }: { week: WeekSummary }) {
  const t = useTranslations("admin.dashboard");
  return (
    <span className="inline-flex items-center gap-1" role="img" aria-label={t("weekDotsAria", { done: week.done, scheduled: week.scheduled })}>
      {week.dots.map((d, i) => (
        <span
          key={i}
          style={{
            width: 8,
            height: 8,
            borderRadius: 999,
            background: d === "DONE" ? "var(--improvement)" : d === "MISSED" ? "var(--heart)" : "transparent",
            boxShadow: d === "UPCOMING" ? "inset 0 0 0 1.5px var(--text-3)" : undefined,
          }}
        />
      ))}
    </span>
  );
}

/** One client in the grid (W7-A): who, when they last did anything, three real numbers, and what is coming. */
export function ClientCard({ client, week, onRevoke, revoking, overLimit }: ClientCardProps) {
  const t = useTranslations("admin.dashboard");
  const fmt = useFormat();
  const router = useRouter();
  const menuRef = useRef<HTMLButtonElement>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [confirmingRevoke, setConfirmingRevoke] = useState(false);
  const [confirmingArchive, setConfirmingArchive] = useState(false);
  const label = useLastActivityLabel();
  const activity = label(client);
  const name = clientDisplayName(client);
  const weight = weightChange(client.weightTrend);
  const next = week?.next ?? null;

  return (
    <div
      className="relative flex flex-col gap-4 p-5"
      style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }}
      data-testid="client-card"
      data-client-email={client.clientEmail}
    >
      <div className="flex items-center gap-3">
        <Link href={`/admin/clients/${client.clientId}`} className="flex items-center gap-3 flex-1 min-w-0">
          <ClientAvatar clientId={client.clientId} email={client.clientEmail} size={44} />
          <span className="flex flex-col min-w-0">
            <span className="truncate" style={{ fontSize: 16, fontWeight: 800 }}>{name}</span>
            <span className="truncate type-body-s" style={{ color: activity.alert ? "var(--heart)" : "var(--text-2)", fontWeight: activity.alert ? 700 : 400 }}>
              {activity.text}
            </span>
          </span>
        </Link>
        <button
          ref={menuRef}
          type="button"
          onClick={() => setMenuOpen(true)}
          aria-label={t("cardMenuAria")}
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          className="lifey-button inline-flex items-center justify-center shrink-0"
          style={{ width: 32, height: 32, borderRadius: "var(--r-control)", color: "var(--text-2)" }}
        >
          <Icon name="more_horiz" size={22} />
        </button>
      </div>

      <dl className="grid grid-cols-3 gap-2">
        <Kpi label={t("kpiCalories")}>
          {client.avgCalories7d != null ? (
            <>
              <span className="num">{fmt.number(client.avgCalories7d, 0)}</span> <Unit>kcal</Unit>
            </>
          ) : (
            <Dash />
          )}
        </Kpi>
        <Kpi label={t("kpiWorkouts")}>
          {week && week.scheduled > 0 ? (
            <>
              <span className="num">{week.done} / {week.scheduled}</span>
              <div className="mt-1.5"><WeekDots week={week} /></div>
            </>
          ) : (
            <Dash />
          )}
        </Kpi>
        <Kpi label={t("kpiWeight")}>
          {weight ? (
            <>
              <span className="num">{fmt.number(weight.latestKg, 1)}</span> <Unit>kg</Unit>
              {weight.deltaKg != null && (
                <div className="mt-1"><DeltaChip value={weight.deltaKg} unit="kg" size="small" /></div>
              )}
            </>
          ) : (
            <span className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>{t("noWeighIn")}</span>
          )}
        </Kpi>
      </dl>

      <div className="flex items-center gap-2 type-body-s" style={{ color: "var(--text-2)" }}>
        <Icon name="event" size={18} color="var(--text-3)" />
        {next ? (
          <span className="truncate">
            {sessionDay(fmt, next.scheduledFor)}
            {next.templateName ? ` · ${next.templateName}` : ""}
          </span>
        ) : week && week.missedDates.length > 0 ? (
          <span style={{ color: "var(--heart)", fontWeight: 600 }}>
            {t("missedOn", { days: week.missedDates.map((d) => fmt.weekdayShort(new Date(d + "T00:00:00"))).join(", ") })}
          </span>
        ) : (
          <span>{t("notScheduled")}</span>
        )}
      </div>

      {overLimit && (
        <Button variant="secondary" fullWidth onClick={() => setConfirmingArchive(true)} disabled={revoking} data-testid="archive-client-inline">
          <Icon name="archive" size={18} />
          {t("archiveClient")}
        </Button>
      )}

      <Menu
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        anchorRef={menuRef}
        items={[
          { label: t("openClient"), icon: "open_in_new", onSelect: () => router.push(`/admin/clients/${client.clientId}`) },
          { label: t("endRelationship"), icon: "link_off", destructive: true, onSelect: () => setConfirmingRevoke(true) },
        ]}
      />

      <ConfirmModal
        open={confirmingRevoke}
        onClose={() => setConfirmingRevoke(false)}
        onConfirm={() => {
          setConfirmingRevoke(false);
          onRevoke(client.clientId);
        }}
        title={t("endRelationshipConfirmTitle")}
        body={t("endRelationshipConfirmBody", { name })}
        icon="link_off"
        cancelLabel={t("cancel")}
        confirmLabel={t("endRelationshipConfirm")}
      />

      <Modal open={confirmingArchive} onClose={() => setConfirmingArchive(false)} width={480} aria-label={t("archiveClientConfirmTitle", { name })}>
        <div className="flex flex-col gap-4 p-6" data-testid="archive-client-confirm">
          <h2 className="type-title-l">{t("archiveClientConfirmTitle", { name })}</h2>
          <p className="type-body" style={{ color: "var(--text-2)" }}>{t("archiveClientConfirmBody", { name })}</p>
          <div className="flex justify-end gap-2" data-autofocus-group>
            <Button variant="secondary" data-autofocus onClick={() => setConfirmingArchive(false)}>{t("cancel")}</Button>
            <Button
              variant="danger"
              disabled={revoking}
              data-testid="archive-client-confirm-submit"
              onClick={() => {
                setConfirmingArchive(false);
                onRevoke(client.clientId);
              }}
            >
              {t("archiveClientConfirm")}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}

/** "H, szept. 29." from an ISO date. */
export function sessionDay(fmt: ReturnType<typeof useFormat>, iso: string): string {
  const d = new Date(iso + "T00:00:00");
  return `${fmt.weekdayShort(d)}, ${fmt.shortDate(d)}`;
}

function Kpi({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1 p-2.5 min-w-0" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
      <dt className="type-body-s truncate" style={{ color: "var(--text-2)", fontSize: 12 }}>{label}</dt>
      <dd style={{ fontSize: 17, fontWeight: 800, lineHeight: 1.15 }}>{children}</dd>
    </div>
  );
}

const Unit = ({ children }: { children: React.ReactNode }) => (
  <span className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>{children}</span>
);
const Dash = () => <span style={{ color: "var(--text-3)" }}>—</span>;
