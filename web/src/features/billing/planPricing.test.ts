import { describe, expect, it } from "vitest";
import { PLANS } from "@/lib/pricing";
import { isCurrentPlan, planIdToTrainerPlan, planOptionsFor, trainerPlanToPlanId } from "./planPricing";

/**
 * Prompt 5's own *Verify* line (docs/landing_page/66-trainer-billing-web-plan.md
 * §7): "a unit test that the rendered prices come from the shared PLANS
 * constant." `PlanChooser.tsx` renders `planOptionsFor(interval)[i].priceHuf`
 * directly with no further transformation, so asserting this function's
 * output against `PLANS` *is* that guarantee — the same shape of test
 * `lib/pricing.test.ts` already uses for `buildPricingOffers`.
 */
describe("planOptionsFor", () => {
  it("monthly prices come straight from PLANS.monthlyPriceHuf, in PLANS's own order", () => {
    const options = planOptionsFor("MONTHLY");
    expect(options).toHaveLength(PLANS.length);
    options.forEach((option, i) => {
      expect(option.priceHuf).toBe(PLANS[i].monthlyPriceHuf);
      expect(option.id).toBe(PLANS[i].id);
      expect(option.seats).toBe(PLANS[i].seats);
      expect(option.recommended).toBe(PLANS[i].recommended);
    });
  });

  it("yearly prices come straight from PLANS.yearlyPriceHuf", () => {
    const options = planOptionsFor("YEARLY");
    options.forEach((option, i) => {
      expect(option.priceHuf).toBe(PLANS[i].yearlyPriceHuf);
    });
  });

  it("never hand-types a price a second time — editing PLANS moves both intervals with it", () => {
    expect(planOptionsFor("MONTHLY").map((o) => o.priceHuf)).toEqual(PLANS.map((p) => p.monthlyPriceHuf));
    expect(planOptionsFor("YEARLY").map((o) => o.priceHuf)).toEqual(PLANS.map((p) => p.yearlyPriceHuf));
  });
});

describe("trainerPlanToPlanId / planIdToTrainerPlan", () => {
  it("round-trip every real plan", () => {
    for (const plan of PLANS) {
      const trainerPlan = planIdToTrainerPlan(plan.id);
      expect(trainerPlanToPlanId(trainerPlan)).toBe(plan.id);
    }
  });

  it("matches the backend's com.lifey.billing.entity.TrainerPlan literals exactly", () => {
    expect(planIdToTrainerPlan("starter")).toBe("STARTER");
    expect(planIdToTrainerPlan("pro")).toBe("PRO");
    expect(planIdToTrainerPlan("studio")).toBe("STUDIO");
  });
});

describe("isCurrentPlan", () => {
  it("marks exactly the option matching the trainer's current plan", () => {
    const options = planOptionsFor("YEARLY");
    const proOption = options.find((o) => o.trainerPlan === "PRO")!;
    const starterOption = options.find((o) => o.trainerPlan === "STARTER")!;

    expect(isCurrentPlan(proOption, "PRO")).toBe(true);
    expect(isCurrentPlan(starterOption, "PRO")).toBe(false);
  });

  it("marks nothing when the trainer has no subscription row yet", () => {
    const options = planOptionsFor("YEARLY");
    expect(options.some((o) => isCurrentPlan(o, null))).toBe(false);
  });
});
