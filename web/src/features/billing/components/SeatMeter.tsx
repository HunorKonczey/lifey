"use client";

import { useTranslations } from "next-intl";

/**
 * `11 / 25 active clients` + pending invites shown separately, since pending
 * invites already count toward the limit (64 §4.3) — hiding them would make
 * "why can't I invite" unanswerable from this page alone (66 §8 edge case 4).
 */
export function SeatMeter({
  activeClients,
  maxClients,
  pendingCount,
}: {
  activeClients: number;
  maxClients: number | null;
  pendingCount: number;
}) {
  const t = useTranslations("admin.billing");
  const overLimit = maxClients != null && activeClients > maxClients;
  const pct = maxClients != null && maxClients > 0 ? Math.min(100, (activeClients / maxClients) * 100) : 0;

  return (
    <div className="rounded-[var(--r-lg)] p-4.5" style={{ background: "var(--surface-container)" }}>
      <div className="flex items-center justify-between mb-2">
        <p className="text-sm font-extrabold" style={{ color: "var(--on-surface)" }}>
          {t("seatMeterTitle")}
        </p>
        <p
          className="text-sm font-bold tabular-nums"
          style={{ color: overLimit ? "var(--error)" : "var(--on-surface-variant)" }}
        >
          {maxClients != null
            ? t("seatCount", { active: activeClients, max: maxClients })
            : t("seatCountUnlimited", { active: activeClients })}
        </p>
      </div>
      {maxClients != null && (
        <div className="h-2 rounded-full overflow-hidden" style={{ background: "var(--surface-highest)" }}>
          <div
            className="h-full rounded-full transition-all"
            style={{ width: `${pct}%`, background: overLimit ? "var(--error)" : "var(--tertiary)" }}
          />
        </div>
      )}
      {pendingCount > 0 && (
        <p className="text-xs mt-2" style={{ color: "var(--on-surface-variant)" }}>
          {t("pendingInvitesCount", { count: pendingCount })}
        </p>
      )}
    </div>
  );
}
