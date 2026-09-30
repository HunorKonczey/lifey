"use client";

import { useTranslations, useLocale } from "next-intl";
import { useFormat } from "@/lib/i18n/format";
import { ActivityChip } from "@/features/workouts/components/ActivityChip";
import { buildCardioSummaryLine } from "@/features/workouts/cardioSummaryLine";
import { Skeleton } from "@/components/status/Skeleton";
import type { WorkoutSessionResponse } from "@/features/workouts/types";
import type { DashboardData } from "../useDashboardData";

/** W1.1 shell for the old recent-workouts card (unchanged); replaced by
 *  `RecentWorkouts` (W1.10). */
export function RecentWorkoutsSection({ data }: { data: DashboardData }) {
  const t = useTranslations("dashboard");
  const tw = useTranslations("workouts");
  const ta = useTranslations("workouts.activityTypes");
  const locale = useLocale();
  const fmt = useFormat();
  const recentSessions = data.sessionsDesc.slice(0, 5);

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <p className="text-sm font-bold mb-3">{t("recentWorkouts")}</p>
      {data.queries.sessionsQ.isLoading ? (
        <Skeleton variant="table" />
      ) : recentSessions.length === 0 ? (
        <p className="text-sm py-4 text-center" style={{ color: "var(--on-surface-variant)" }}>
          {t("noWorkoutsYet")}
        </p>
      ) : (
        <div className="flex flex-col gap-2">
          {recentSessions.map((s: WorkoutSessionResponse) => {
            const isCardio = s.sessionKind === "CARDIO";
            return (
              <div key={s.id} className="flex items-center gap-3 py-2 border-b last:border-0" style={{ borderColor: "var(--outline)" }}>
                {isCardio && <ActivityChip activityType={s.activityType} />}
                <div className="flex-1 min-w-0 flex items-center justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-sm font-semibold truncate">
                      {isCardio
                        ? ta(s.activityType ?? "OTHER_CARDIO")
                        : s.templateName ?? (s.exercises.map((e) => e.exerciseName).join(", ") || t("workoutFallback"))}
                    </p>
                    <p className="text-xs" style={{ color: "var(--muted)" }}>
                      {fmt.date(s.startedAt, "dayTime")}
                    </p>
                  </div>
                  {isCardio ? (
                    <span className="text-xs font-semibold shrink-0 tabular" style={{ color: "var(--on-surface-variant)" }}>
                      {buildCardioSummaryLine(s, tw, locale)}
                    </span>
                  ) : (
                    s.finishedAt && (
                      <span className="text-xs font-semibold shrink-0" style={{ color: "var(--on-surface-variant)" }}>
                        {Math.round((new Date(s.finishedAt).getTime() - new Date(s.startedAt).getTime()) / 60000)} {t("minutes")}
                      </span>
                    )
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
