import { PLANS, type PlanId } from "@/lib/pricing";
import type { BillingInterval, TrainerPlan } from "./types";

/** `PLANS[i].id` is lowercase ("pro"); the backend's TrainerPlan enum is upper ("PRO") — same word, different case, never a separate lookup table. */
export function trainerPlanToPlanId(plan: TrainerPlan): PlanId {
  return plan.toLowerCase() as PlanId;
}

export function planIdToTrainerPlan(id: PlanId): TrainerPlan {
  return id.toUpperCase() as TrainerPlan;
}

export interface PlanChooserOption {
  id: PlanId;
  trainerPlan: TrainerPlan;
  seats: string | null;
  recommended: boolean;
  priceHuf: number;
}

/**
 * The plan chooser's three cards for a given interval — prices read straight
 * from the shared `PLANS` constant (65 D-W9/§10.4), never hand-typed a second
 * time (docs/landing_page/66-trainer-billing-web-plan.md §9 risk 6).
 */
export function planOptionsFor(interval: BillingInterval): PlanChooserOption[] {
  return PLANS.map((plan) => ({
    id: plan.id,
    trainerPlan: planIdToTrainerPlan(plan.id),
    seats: plan.seats,
    recommended: plan.recommended,
    priceHuf: interval === "YEARLY" ? plan.yearlyPriceHuf : plan.monthlyPriceHuf,
  }));
}

export function isCurrentPlan(option: PlanChooserOption, currentPlan: TrainerPlan | null): boolean {
  return currentPlan !== null && option.trainerPlan === currentPlan;
}
