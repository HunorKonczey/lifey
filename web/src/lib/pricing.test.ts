import { describe, expect, it } from "vitest";
import { PLANS, MOBILE_PRO, buildPricingOffers, formatHuf, monthlyEquivalent } from "./pricing";

describe("buildPricingOffers", () => {
  it("prices come from the same PLANS constant the pricing page renders (65 §5.2)", () => {
    const offers = buildPricingOffers("https://lifey.hu/hu/arak");
    expect(offers).toHaveLength(PLANS.length);
    offers.forEach((offer, i) => {
      expect(offer.name).toBe(PLANS[i].id);
      expect(offer.price).toBe(String(PLANS[i].monthlyPriceHuf));
      expect(offer.priceCurrency).toBe("HUF");
    });
  });

  it("never hand-types a price a second time", () => {
    // If someone edits PLANS, the offers must move with it — not require a
    // second edit here or in the page.
    const offers = buildPricingOffers("https://lifey.hu/hu/arak");
    expect(offers.map((o) => o.price)).toEqual(PLANS.map((p) => String(p.monthlyPriceHuf)));
  });
});

describe("monthlyEquivalent", () => {
  it("matches the delivered canvas's per-month figures (design/Lifey Landing.dc.html L19)", () => {
    expect(monthlyEquivalent(49_900)).toBe(4_158);
    expect(monthlyEquivalent(129_900)).toBe(10_825);
    expect(monthlyEquivalent(249_900)).toBe(20_825);
  });
});

describe("DV-5 (68 §12.2) — the phantom Studio feature stays fixed", () => {
  it("does not resurface as a plan field", () => {
    for (const plan of PLANS) {
      expect(JSON.stringify(plan)).not.toMatch(/több edző|multiple trainers/i);
    }
  });
});

describe("formatHuf", () => {
  it("thousand-separates and appends Ft", () => {
    // Intl.NumberFormat("hu-HU") uses a narrow no-break space (U+202F) as
    // the thousands separator, not a regular space — compare structurally
    // instead of hard-coding that character in a string literal.
    const result = formatHuf(MOBILE_PRO.yearlyHuf);
    expect(result.endsWith(" Ft")).toBe(true);
    expect(result.replace(/\s/g, "")).toBe("11900Ft");
  });
});
