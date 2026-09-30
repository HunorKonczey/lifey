"use client";

import { useTranslations } from "next-intl";
import { Button, Card, Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { walkingMinutes } from "../walking";

const STEPS = "var(--metric-steps)";

/**
 * The steps page's hero (W4.6, W4-C, client-023): "Ma eddig", **6 412** large, "Még 2 588 a 9 000-es célig · kb. 25
 * perc séta" — or, past the goal, a ✓ and "Cél elérve" in the *same* purple: reaching it does not switch the metric to a
 * second colour — and "✎ Szerkesztés", which opens the small edit drawer for that day's count.
 */
export function StepsHero({
  steps,
  goal,
  isToday,
  date,
  onEdit,
}: {
  steps: number;
  goal: number;
  isToday: boolean;
  date: Date;
  onEdit: () => void;
}) {
  const t = useTranslations("steps");
  const fmt = useFormat();
  const left = goal - steps;
  const reached = steps >= goal;

  return (
    <Card variant="hero" className="flex flex-col gap-3" style={{ padding: 28 }} data-testid="steps-hero">
      <div className="flex items-start justify-between gap-3">
        <span className="type-section" style={{ color: "var(--text-3)" }}>
          {isToday ? t("heroToday") : t("heroOn", { date: fmt.shortDate(date) })}
        </span>
        <Button variant="secondary" onClick={onEdit}>
          <Icon name="edit" size={18} />
          {t("edit")}
        </Button>
      </div>
      <p className="type-display-xl tabular" style={{ color: "var(--text)" }} data-testid="steps-number">
        {fmt.integer(steps)}
      </p>
      <p className="type-body" style={{ color: "var(--text-2)" }} data-testid="steps-remaining">
        {reached ? (
          <span className="inline-flex items-center gap-1" style={{ color: STEPS, fontWeight: 700 }}>
            <Icon name="check_circle" size={18} fill={1} color={STEPS} />
            {t("heroReached", { goal: fmt.integer(goal) })}
          </span>
        ) : (
          t("heroLeft", { left: fmt.integer(left), goal: fmt.integer(goal), minutes: walkingMinutes(left) })
        )}
      </p>
    </Card>
  );
}
