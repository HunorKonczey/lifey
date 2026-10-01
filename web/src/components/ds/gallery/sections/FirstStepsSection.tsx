"use client";

import { FirstStepsView } from "@/features/dashboard/components/FirstSteps";
import { firstStepsState } from "@/features/dashboard/firstSteps";

const noop = () => {};

/** The new account's card (W1.11): goals already set (the canvas), nothing
 *  done, and after the first meal was logged. */
export function FirstStepsSection() {
  return (
    <div className="grid gap-6 lg:grid-cols-3">
      <div data-state="goals-done">
        <FirstStepsView
          name="Anna"
          state={firstStepsState({ hasGoal: true, hasMeal: false, hasWeight: false })}
          goalsSummary="1,850 kcal · 110 g protein"
          onStep={noop}
          onDismiss={noop}
        />
      </div>
      <div data-state="nothing-done">
        <FirstStepsView name="Anna" state={firstStepsState({ hasGoal: false, hasMeal: false, hasWeight: false })} onStep={noop} onDismiss={noop} />
      </div>
      <div data-state="meal-done">
        <FirstStepsView
          name="Anna"
          state={firstStepsState({ hasGoal: true, hasMeal: true, hasWeight: false })}
          goalsSummary="1,850 kcal · 110 g protein"
          onStep={noop}
        />
      </div>
    </div>
  );
}
