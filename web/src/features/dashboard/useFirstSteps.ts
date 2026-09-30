"use client";

import { useCallback, useEffect, useState } from "react";
import { firstStepsState, showFirstSteps } from "./firstSteps";
import type { DashboardData } from "./useDashboardData";

const DISMISSED_KEY = "lifey-first-steps-dismissed";

function readDismissed(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return localStorage.getItem(DISMISSED_KEY) === "1";
  } catch {
    return false;
  }
}

/**
 * Whether the dashboard shows the first-steps card (W1.11) and the state it
 * renders. Only decided once the meals and weights have actually loaded — a
 * card flashing for an established account while those queries are in flight
 * would be wrong — and pinned once a fresh account has seen it, so the step
 * the user just completed ticks on screen instead of the card vanishing.
 * Dismissal is per browser, like the onboarding banner it replaces.
 */
export function useFirstSteps(data: DashboardData) {
  const [dismissed, setDismissed] = useState(readDismissed);
  const [pinned, setPinned] = useState(false);

  const { mealsQ, weightsQ } = data.queries;
  const ready = mealsQ.isSuccess && weightsQ.isSuccess;
  const state = firstStepsState({
    hasGoal: (data.settings?.dailyCalorieGoal ?? 0) > 0,
    hasMeal: data.meals.length > 0,
    hasWeight: data.weightsAsc.length > 0,
  });

  const fresh = ready && state.fresh;
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- latch: stays true once a fresh account has seen the card
    if (fresh) setPinned(true);
  }, [fresh]);

  const dismiss = useCallback(() => {
    try {
      localStorage.setItem(DISMISSED_KEY, "1");
    } catch {
      /* ignore */
    }
    setDismissed(true);
  }, []);

  return { show: ready && showFirstSteps(state, { pinned, dismissed }), state, dismiss };
}
