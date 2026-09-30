"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useLocale, useTranslations } from "next-intl";
import { Button, Card, Icon, RecordChip } from "@/components/ds";
import { EmptyState } from "@/components/status/EmptyState";
import { useFormat } from "@/lib/format/useFormat";
import { activityTypeIcon } from "@/features/workouts/activityType";
import { buildCardioSummaryLine } from "@/features/workouts/cardioSummaryLine";
import type { WorkoutSessionResponse } from "@/features/workouts/types";
import type { DashboardData } from "../useDashboardData";

const ROWS = 4;

export interface RecentWorkoutRow {
  id: number;
  kind: "strength" | "cardio";
  name: string;
  /** One line: duration · volume · sets, or pace · distance for cardio. */
  meta: string;
  /** "yesterday" / "Sep 25" — already formatted. */
  dateLabel: string;
  icon: string;
  isPr: boolean;
}

export interface RecentWorkoutsViewProps {
  rows: RecentWorkoutRow[];
  onOpen?: (id: number) => void;
  onStart?: () => void;
}

/**
 * The dashboard's recent-workouts list (W1.10, client-001): a 40px tinted
 * icon (strength in the primary tint, cardio in the heart tint), the name
 * with a 🏆 PR chip when that session set a record, one meta line, and a
 * relative date on the right. Below 640px the fourth row drops (W1-C shows
 * three). An empty account gets a short prompt instead of an empty card.
 */
export function RecentWorkoutsView({ rows, onOpen, onStart }: RecentWorkoutsViewProps) {
  const t = useTranslations("dashboard");

  return (
    <Card style={{ padding: "16px 0 8px" }} className="h-full" data-testid="recent-workouts">
      <div className="flex items-center justify-between px-5 pb-2">
        <h3 style={{ fontSize: 16, fontWeight: 800 }}>{t("recentWorkouts")}</h3>
        <Link href="/workouts" className="type-body-s" style={{ color: "var(--primary)", fontWeight: 700 }}>
          {t("recentAll")}
        </Link>
      </div>

      {rows.length === 0 ? (
        <EmptyState
          compact
          icon="fitness_center"
          title={t("noWorkoutsYet")}
          body={t("recentEmptyBody")}
          action={
            <Button variant="secondary" onClick={onStart}>
              {t("startWorkoutCta")}
            </Button>
          }
        />
      ) : (
        <ul className="flex flex-col">
          {rows.map((r, i) => {
            const tint = r.kind === "strength" ? "var(--primary)" : "var(--heart)";
            return (
              <li key={r.id} className={i >= 3 ? "hidden sm:block" : undefined}>
                <button
                  type="button"
                  onClick={() => onOpen?.(r.id)}
                  className="lifey-button flex w-full items-center gap-3 px-5 py-2.5 text-left"
                  style={{ minHeight: 60 }}
                >
                  <span
                    className="flex shrink-0 items-center justify-center"
                    style={{
                      width: 40,
                      height: 40,
                      borderRadius: "var(--r-control)",
                      background: `color-mix(in srgb, ${tint} var(--chip-tint), transparent)`,
                    }}
                  >
                    <Icon name={r.icon} size={22} fill={1} color={tint} />
                  </span>
                  <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span className="flex items-center gap-2">
                      <span className="truncate" style={{ fontSize: 15, fontWeight: 700 }}>
                        {r.name}
                      </span>
                      {r.isPr && <RecordChip label={t("recentPr")} />}
                    </span>
                    <span className="type-body-s truncate tabular" style={{ color: "var(--text-2)" }}>
                      {r.meta}
                    </span>
                  </span>
                  <span className="type-body-s shrink-0" style={{ color: "var(--text-3)" }}>
                    {r.dateLabel}
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}

function strengthMeta(
  s: WorkoutSessionResponse,
  t: ReturnType<typeof useTranslations>,
  fmt: ReturnType<typeof useFormat>,
): string {
  const parts: string[] = [];
  if (s.finishedAt) {
    const minutes = Math.round((new Date(s.finishedAt).getTime() - new Date(s.startedAt).getTime()) / 60_000);
    if (minutes > 0) parts.push(t("recentDuration", { n: minutes }));
  } else {
    parts.push(t("recentInProgress"));
  }
  const volume = s.sets.reduce((sum, set) => sum + set.weight * set.reps, 0);
  if (volume > 0) parts.push(fmt.integer(volume, "kg"));
  if (s.sets.length > 0) parts.push(t("recentSets", { n: s.sets.length }));
  return parts.join(" · ");
}

export function RecentWorkouts({ data }: { data: DashboardData }) {
  const t = useTranslations("dashboard");
  const tw = useTranslations("workouts");
  const fmt = useFormat();
  const locale = useLocale();
  const router = useRouter();
  const now = new Date();

  const rows: RecentWorkoutRow[] = data.sessionsDesc.slice(0, ROWS).map((s) => {
    const cardio = s.sessionKind === "CARDIO";
    return {
      id: s.id,
      kind: cardio ? "cardio" : "strength",
      name: cardio
        ? fmt.activityLabel(s.activityType ?? "OTHER_CARDIO")
        : (s.templateName ?? (s.exercises.map((e) => e.exerciseName).join(", ") || t("workoutFallback"))),
      meta: cardio ? buildCardioSummaryLine(s, tw, locale) : strengthMeta(s, t, fmt),
      dateLabel: fmt.relativeDay(new Date(s.startedAt), now),
      icon: activityTypeIcon(cardio ? s.activityType : "STRENGTH"),
      isPr: (data.sessionRecords.get(s.id) ?? 0) > 0,
    };
  });

  return (
    <RecentWorkoutsView
      rows={rows}
      onOpen={(id) => router.push(`/workouts?open=${id}`)}
      onStart={() => router.push("/workouts")}
    />
  );
}
