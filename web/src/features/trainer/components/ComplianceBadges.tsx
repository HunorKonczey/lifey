"use client";

import { useTranslations } from "next-intl";
import { complianceFor } from "../compliance";
import type { TrainerClientResponse } from "../types";

interface ComplianceBadgesProps {
  client: TrainerClientResponse;
}

/** Warning chips shown only for flagged clients (docs/29) — absent entirely for compliant ones. */
export function ComplianceBadges({ client }: ComplianceBadgesProps) {
  const t = useTranslations("admin.dashboard");
  const flags = complianceFor(client);

  if (!flags.needsAttention) return null;

  return (
    <div className="mt-2.5 flex flex-wrap items-center gap-1.5">
      {flags.inactive && (
        <Badge icon="schedule" label={t("inactiveBadge", { count: flags.daysSinceLastLog })} />
      )}
      {flags.hasMissedWorkouts && (
        <Badge icon="event_busy" label={t("missedWorkoutsBadge", { count: flags.missedWorkouts })} />
      )}
      {flags.weightStale && (
        <Badge icon="monitor_weight" label={t("weightStaleBadge", { count: flags.daysSinceWeight })} />
      )}
    </div>
  );
}

function Badge({ icon, label }: { icon: string; label: string }) {
  return (
    <span
      className="flex items-center gap-1 rounded-[var(--r-pill)] text-[11px] font-bold px-2.5 py-1"
      style={{ background: "var(--error-container)", color: "var(--error)" }}
    >
      <span className="material-symbols-rounded text-[14px]">{icon}</span>
      {label}
    </span>
  );
}
