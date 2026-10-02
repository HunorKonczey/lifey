"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Button, Card, Icon, IconButton } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { usePageShortcuts } from "@/lib/hooks/usePageShortcuts";
import { useSessionStore } from "@/features/auth/store";
import { AddFoodFlow } from "@/features/nutrition/components/addFood/AddFoodFlow";
import type { FirstStepId, FirstStepsState } from "../firstSteps";
import type { DashboardData } from "../useDashboardData";

const STEP_ICON: Record<FirstStepId, { icon: string; color: string }> = {
  goals: { icon: "flag", color: "var(--primary)" },
  meal: { icon: "restaurant", color: "var(--m-kcal)" },
  weight: { icon: "monitor_weight", color: "var(--m-weight)" },
};

export interface FirstStepsViewProps {
  name: string;
  state: FirstStepsState;
  /** "1 850 kcal · 110 g protein" — what the goals step says once it's done. */
  goalsSummary?: string;
  onStep: (id: FirstStepId) => void;
  onDismiss?: () => void;
}

/**
 * The new account's dashboard (W1.11, W1-D): instead of a zeroed hero and
 * tiles, a greeting and three steps — goals, first meal, first weight — each
 * with a state icon and, while pending, its own button. A done step shows a
 * filled check and goes quiet; steps complete independently. Presentational,
 * so the gallery can show every state.
 */
export function FirstStepsView({ name, state, goalsSummary, onStep, onDismiss }: FirstStepsViewProps) {
  const t = useTranslations("dashboard");

  const copy: Record<FirstStepId, { title: string; detail: string; cta: string }> = {
    goals: {
      title: state.steps[0].done ? t("stepGoalsTitle") : t("stepGoalsPending"),
      detail: state.steps[0].done ? (goalsSummary ?? "") : "",
      cta: t("stepGoalsCta"),
    },
    meal: { title: t("stepMealTitle"), detail: t("stepMealBody"), cta: t("stepMealCta") },
    weight: { title: t("stepWeightTitle"), detail: t("stepWeightBody"), cta: t("stepWeightCta") },
  };

  return (
    <Card variant="hero" className="flex flex-col gap-5" style={{ padding: 26 }} data-testid="first-steps">
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-col gap-1.5">
          <h2 style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-0.02em", textWrap: "balance" }}>{t("firstStepsTitle", { name })}</h2>
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>
            {t("firstStepsBody")}
          </p>
        </div>
        {onDismiss && <IconButton icon="close" label={t("firstStepsDismiss")} size={32} onClick={onDismiss} />}
      </div>

      <ol className="flex flex-col py-1" style={{ background: "var(--nested)", borderRadius: 22 }}>
        {state.steps.map(({ id, done }) => {
          const { icon, color } = STEP_ICON[id];
          const c = copy[id];
          return (
            <li key={id} data-step={id} data-done={done} className="flex items-center gap-3.5 px-4 py-3">
              <span
                className="flex shrink-0 items-center justify-center"
                style={{
                  width: 32,
                  height: 32,
                  borderRadius: "var(--r-pill)",
                  background: done ? "var(--primary)" : "var(--control)",
                  color: done ? "var(--on-primary)" : color,
                }}
              >
                {done ? <Icon name="check" size={18} label={t("stepDone")} /> : <Icon name={icon} size={18} fill={1} />}
              </span>
              <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                <span style={{ fontSize: 15, fontWeight: 700, color: done ? "var(--text-2)" : "var(--text)" }}>{c.title}</span>
                {c.detail && (
                  <span className="type-body-s" style={{ color: "var(--text-2)" }}>
                    {c.detail}
                  </span>
                )}
              </span>
              {!done && (
                <Button onClick={() => onStep(id)} className="shrink-0">
                  {c.cta}
                </Button>
              )}
            </li>
          );
        })}
      </ol>
    </Card>
  );
}

/** The connected card: real steps, the add-meal dialog for step 2, the `N`
 *  shortcut (the hero that normally owns it isn't on screen), and routes for
 *  goals (onboarding) and weight (the weight page until its drawer exists). */
export function FirstSteps({
  data,
  state,
  onDismiss,
}: {
  data: DashboardData;
  state: FirstStepsState;
  onDismiss: () => void;
}) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();
  const router = useRouter();
  const firstName = useSessionStore((s) => s.user?.firstName) ?? "";
  const [adding, setAdding] = useState(false);

  const openAdd = useCallback(() => setAdding(true), []);
  usePageShortcuts({ onNew: openAdd, newLabel: t("addMeal") });

  const { settings } = data;
  const goalsSummary = [
    settings?.dailyCalorieGoal ? fmt.integer(settings.dailyCalorieGoal, "kcal") : null,
    settings?.dailyProteinGoal ? `${fmt.integer(settings.dailyProteinGoal)} g ${t("protein").toLocaleLowerCase(fmt.locale)}` : null,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <>
      <FirstStepsView
        name={firstName}
        state={state}
        goalsSummary={goalsSummary}
        onDismiss={onDismiss}
        onStep={(id) => {
          if (id === "goals") router.push("/onboarding");
          else if (id === "meal") openAdd();
          else router.push("/weight");
        }}
      />
      {adding && <AddFoodFlow date={data.date} onClose={() => setAdding(false)} />}
    </>
  );
}
