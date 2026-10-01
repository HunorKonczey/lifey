"use client";

import { useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { RatioBar } from "@/components/ds/progress/RatioBar";

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

  return (
    <Card className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-3">
        <h2 className="type-body" style={{ fontWeight: 800 }}>{t("seatMeterTitle")}</h2>
        <p className="type-body-s tabular" style={{ fontWeight: 700, color: overLimit ? "var(--heart)" : "var(--text-2)" }}>
          {maxClients != null
            ? t("seatCount", { active: activeClients, max: maxClients })
            : t("seatCountUnlimited", { active: activeClients })}
        </p>
      </div>
      {maxClients != null && maxClients > 0 && (
        <RatioBar segments={[{ value: Math.min(activeClients, maxClients), color: overLimit ? "var(--heart)" : "var(--primary)" }]} total={maxClients} />
      )}
      {pendingCount > 0 && (
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>
          {t("pendingInvitesCount", { count: pendingCount })}
        </p>
      )}
    </Card>
  );
}
