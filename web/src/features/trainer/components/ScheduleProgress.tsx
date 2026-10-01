"use client";

import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";

/**
 * The adherence line shared by the schedule and program cards (W7.12): done · missed · remaining counts with a stacked bar —
 * done in the improvement green, missed in heart, the rest the empty track. The meaning is in the words, never the colour alone.
 */
export function ScheduleProgress({ done, missed, remaining }: { done: number; missed: number; remaining: number }) {
  const t = useTranslations("admin.schedule");
  const total = done + missed + remaining;
  const donePct = total > 0 ? (done / total) * 100 : 0;
  const missedPct = total > 0 ? (missed / total) * 100 : 0;
  return (
    <div className="flex flex-col gap-2.5">
      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 type-body-s" style={{ fontWeight: 700 }}>
        <span className="inline-flex items-center gap-1.5" style={{ color: "var(--improvement)" }}>
          <Icon name="check_circle" size={16} fill={1} />
          {t("doneCount", { count: done })}
        </span>
        {missed > 0 && (
          <span className="inline-flex items-center gap-1.5" style={{ color: "var(--heart)" }}>
            <Icon name="warning" size={16} />
            {t("missedCount", { count: missed })}
          </span>
        )}
        <span className="inline-flex items-center gap-1.5" style={{ color: "var(--text-2)" }}>
          <Icon name="schedule" size={16} />
          {t("remainingCount", { count: remaining })}
        </span>
      </div>
      <div className="flex overflow-hidden" style={{ height: 6, borderRadius: 3, background: "var(--control)" }} aria-hidden>
        <div style={{ width: `${donePct}%`, background: "var(--improvement)" }} />
        <div style={{ width: `${missedPct}%`, background: "var(--heart)" }} />
      </div>
    </div>
  );
}
