/**
 * The trainer pricing tiers — the one source of truth (65 §10.4 / 63 D-M2)
 * for every place a price appears: this preview, the full pricing page
 * (65 Prompt 6), and its JSON-LD `Offer`s. Never hand-type these numbers a
 * second time anywhere — import this instead.
 *
 * Every plan has every feature (D-M2); only the seat count differs. The
 * third bullet is deliberately identical across all three tiers — the
 * delivered design canvas (L19) had Studio claim "multiple trainers per
 * studio" here, a feature that doesn't exist and is explicitly out of scope
 * (63 §6) — see docs/landing_page/68-web-landing-design-plan.md §12.2 DV-5.
 */
export const PLANS = [
  {
    id: "starter",
    seats: "5",
    yearlyPriceHuf: 49_900,
    monthlyPriceHuf: 4_990,
    recommended: false,
  },
  {
    id: "pro",
    seats: "25",
    yearlyPriceHuf: 129_900,
    monthlyPriceHuf: 12_990,
    recommended: true,
  },
  {
    id: "studio",
    seats: null, // unlimited
    yearlyPriceHuf: 249_900,
    monthlyPriceHuf: 24_990,
    recommended: false,
  },
] as const;

export type PlanId = (typeof PLANS)[number]["id"];

export function formatHuf(amount: number): string {
  return new Intl.NumberFormat("hu-HU").format(amount) + " Ft";
}

/**
 * The yearly price's per-month equivalent, shown as the small line under
 * the headline yearly figure on the pricing page (design/Lifey Landing.dc.html
 * L19, e.g. "4 158 Ft / hó · havi számlázással 4 990 Ft" for Starter — the
 * card's actual monthly-billed price is `PLANS[i].monthlyPriceHuf`, a
 * separate, real number, not derived from this one).
 */
export function monthlyEquivalent(yearlyPriceHuf: number): number {
  return Math.round(yearlyPriceHuf / 12);
}

/**
 * Mobile Pro (63 D-M6) — the individual-user subscription, not a trainer
 * tier. Lives here, not in `67`'s Flutter code, because the pricing page
 * (65 Prompt 6, L19/L20's "Mobil Pro" card) is the first web-side place
 * these numbers appear; the app-side paywall must import the same figures
 * once it's built rather than re-typing them (65 §10 edge case 4).
 */
export const MOBILE_PRO = {
  monthlyHuf: 1_490,
  yearlyHuf: 11_900,
};

/**
 * `Product`/`Offer` JSON-LD for the pricing page (65 §5.2), built from
 * `PLANS` so the structured data can never drift from what the page
 * renders — see pricing.test.ts, which asserts exactly that.
 */
export function buildPricingOffers(pageUrl: string) {
  return PLANS.map((plan) => ({
    "@type": "Offer" as const,
    name: plan.id,
    price: String(plan.monthlyPriceHuf),
    priceCurrency: "HUF",
    availability: "https://schema.org/InStock",
    url: pageUrl,
  }));
}
