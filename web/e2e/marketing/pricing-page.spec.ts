import { test, expect } from "@playwright/test";

/**
 * The pricing page (docs/landing_page/65 Prompt 6, L19/L20) — the interval
 * toggle and the three signed-out plan CTAs. Unlike trainer-flow.spec.ts,
 * this needs no backend/Postgres: the marketing tree is fully static and a
 * signed-out visitor is the default state (no cookie, no token), so this
 * test only needs the Next.js server `playwright.config.ts` already starts.
 *
 * The signed-in CTA swap ("Csomag kezelése" -> /admin/billing,
 * PricingCards.tsx) is not covered here — it needs a real session, and
 * `/admin/billing` itself doesn't exist yet (`66`'s scope). See this
 * prompt's landed notes in `65-web-landing-page-plan.md`.
 */

test.describe("pricing page", () => {
  test("interval toggle switches all three cards between yearly and monthly", async ({ page }) => {
    await page.goto("/hu/arak");

    // Yearly is pre-selected (68 §5.1) — the yearly figure is visible first.
    await expect(page.getByText("49 900 Ft", { exact: false }).first()).toBeVisible();

    await page.getByRole("button", { name: "Havi" }).click();

    // The monthly-billed price replaces the yearly one; the "havi
    // számlázással" equivalent line disappears since it's now redundant.
    await expect(page.getByText("4990 Ft", { exact: false }).first()).toBeVisible();
    await expect(page.getByText("havi számlázással")).toHaveCount(0);

    await page.getByRole("button", { name: "Éves" }).click();
    await expect(page.getByText("49 900 Ft", { exact: false }).first()).toBeVisible();
  });

  test("each plan CTA carries the right ?src attribution and points at /register", async ({ page }) => {
    await page.goto("/hu/arak");

    for (const planId of ["starter", "pro", "studio"]) {
      const cta = page.locator(`a[href="/register?src=pricing-${planId}"]`);
      await expect(cta).toHaveCount(1);
      await expect(cta).toHaveText("Csomagválasztás");
    }
  });

  test("the recommended (Pro) card is visually marked", async ({ page }) => {
    await page.goto("/hu/arak");
    await expect(page.getByText("AJÁNLOTT")).toBeVisible();
  });

  test("billing FAQ accordion opens on click", async ({ page }) => {
    await page.goto("/hu/arak");
    const question = page.getByText("Lemondhatom bármikor?");
    await question.click();
    await expect(
      page.getByText("A lemondás a folyó számlázási időszak végéig", { exact: false })
    ).toBeVisible();
  });
});
