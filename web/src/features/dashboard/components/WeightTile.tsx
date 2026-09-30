"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Button, Card, DeltaChip, Icon, MetricTile } from "@/components/ds";
import { TrendSpark } from "@/components/ds/charts/TrendSpark";
import { EmptyState } from "@/components/status/EmptyState";
import { useFormat } from "@/lib/format/useFormat";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { GOAL_REACHED_TOLERANCE_KG, parseLocalDate } from "@/features/weight/trend";
import type { DashboardData } from "../useDashboardData";

const WEIGHT_COLOR = "var(--metric-weight)";

export interface WeightTileViewProps {
  /** The newest weigh-in, or null for a fresh account. */
  latest: { weight: number; date: Date } | null;
  /** The trend's kg per week, signed like the scale; null while there isn't enough data. */
  pace: number | null;
  goalKg: number | null;
  /** The last weeks of weigh-ins, oldest first, for the small trend line; omit or pass < 2 to hide it. */
  trend?: number[];
  onClick?: () => void;
  onLog?: () => void;
}

/**
 * The dashboard's weight tile (W1.7): the relative date of the last weigh-in
 * ("ma", "tegnap", "szept. 25."), the weight, a weekly-pace chip read from
 * the trend (goal-aware: moving toward the goal is green, away from it the
 * heart colour) and "Cél 65 kg · még 4,6 kg". With no weigh-in yet the tile
 * is a compact empty state that says what to do instead of a zero.
 */
export function WeightTileView({ latest, pace, goalKg, trend, onClick, onLog }: WeightTileViewProps) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();
  const roomy = useMediaQuery("(min-width: 1280px)");

  if (!latest) {
    return (
      <Card className="flex flex-col gap-2" data-testid="weight-empty">
        <div className="flex items-center gap-1.5" style={{ height: 32 }}>
          <Icon name="monitor_weight" size={18} fill={1} color={WEIGHT_COLOR} />
          <span className="type-body-s" style={{ color: "var(--text-2)" }}>
            {t("weight")}
          </span>
        </div>
        <EmptyState
          compact
          icon="monitor_weight"
          color={WEIGHT_COLOR}
          title={t("weightEmptyTitle")}
          body={t("weightEmptyBody")}
          action={
            <Button variant="secondary" onClick={onLog}>
              {t("weightLog")}
            </Button>
          }
        />
      </Card>
    );
  }

  const goalDirection = goalKg == null ? undefined : goalKg < latest.weight ? "lower" : "higher";
  const remaining = goalKg == null ? null : Math.abs(latest.weight - goalKg);
  const goalText = goalKg == null ? "" : Number.isInteger(goalKg) ? fmt.integer(goalKg, "kg") : fmt.weight(goalKg);

  let subline: string | undefined;
  if (goalKg != null && remaining != null) {
    subline = remaining <= GOAL_REACHED_TOLERANCE_KG ? t("weightGoalReached") : t("weightGoalLine", { goal: goalText, left: fmt.weight(remaining) });
  }

  return (
    <MetricTile
      icon="monitor_weight"
      label={t("weight")}
      meta={fmt.relativeDay(latest.date, new Date())}
      value={fmt.weightNumber(latest.weight)}
      unit="kg"
      color={WEIGHT_COLOR}
      delta={
        pace != null ? (
          <DeltaChip value={pace} unit={t(roomy ? "weightPerWeekUnit" : "weightPerWeekShort")} goalDirection={goalDirection} />
        ) : undefined
      }
      subline={subline}
      trailing={
        trend && trend.length >= 2 ? (
          <div className="hidden @[260px]:block">
            <TrendSpark values={trend} color={WEIGHT_COLOR} />
          </div>
        ) : undefined
      }
      onClick={onClick}
      aria-label={`${t("weight")}: ${fmt.weight(latest.weight)}`}
    />
  );
}

export function WeightTile({ data }: { data: DashboardData }) {
  const router = useRouter();
  const { latestWeight, weightPace, goalWeightKg } = data;
  return (
    <WeightTileView
      latest={latestWeight ? { weight: latestWeight.weight, date: parseLocalDate(latestWeight.date) } : null}
      pace={weightPace}
      goalKg={goalWeightKg}
      trend={data.weightsAsc.slice(-30).map((w) => w.weight)}
      onClick={() => router.push("/weight")}
      onLog={() => router.push("/weight")}
    />
  );
}
