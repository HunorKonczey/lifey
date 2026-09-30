"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Icon, MetricTile } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { effectiveDailyStepGoal, walkingMinutes } from "@/features/steps/walking";
import type { DashboardData } from "../useDashboardData";

const STEPS_COLOR = "var(--metric-steps)";

export interface StepsTileViewProps {
  steps: number;
  goal: number;
  onClick?: () => void;
}

/**
 * The dashboard's steps tile (W1.7): one colour — steps purple — for the
 * bar, and a goal that says what's left ("Még 2 588 lépés · kb. 25 perc
 * séta", shortened below 1280) or, once reached, a ✓ and "Cél elérve" in the
 * *same* purple: reaching a goal doesn't switch the metric to a second colour.
 */
export function StepsTileView({ steps, goal, onClick }: StepsTileViewProps) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();
  const roomy = useMediaQuery("(min-width: 1280px)");

  const reached = steps >= goal;
  const left = goal - steps;

  const subline = reached ? (
    <span className="inline-flex items-center gap-1" style={{ color: STEPS_COLOR, fontWeight: 700 }} data-testid="steps-reached">
      <Icon name="check_circle" size={16} fill={1} color={STEPS_COLOR} />
      {t("stepsReached")}
    </span>
  ) : roomy ? (
    t("stepsLeft", { left: fmt.integer(left), minutes: walkingMinutes(left) })
  ) : (
    t("stepsLeftShort", { left: fmt.integer(left), goal: fmt.integer(goal) })
  );

  return (
    <MetricTile
      icon="directions_walk"
      label={t("steps")}
      meta={t("stepsGoalMeta", { goal: fmt.integer(goal) })}
      value={fmt.integer(steps)}
      color={STEPS_COLOR}
      progress={steps / goal}
      subline={subline}
      onClick={onClick}
      aria-label={`${t("steps")}: ${fmt.integer(steps)} / ${fmt.integer(goal)}`}
    />
  );
}

export function StepsTile({ data }: { data: DashboardData }) {
  const router = useRouter();
  return (
    <StepsTileView
      steps={data.todaySteps?.steps ?? 0}
      goal={effectiveDailyStepGoal(data.settings)}
      onClick={() => router.push("/steps")}
    />
  );
}
