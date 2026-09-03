import { test, expect } from "@playwright/test";

/**
 * The two hero CTAs and first-touch attribution (docs/landing_page/65 D-W8,
 * §7 and 72 Prompt 5). `lib/attribution.ts`'s pure functions already have unit
 * tests; what has never been covered end to end is that a real click actually
 * carries `?src=` into registration, and that a real page load writes the
 * cookie.
 */

// The same CTA label appears three times on the home page (hero, sponsored
// band, final CTA) — each with its own `slot`, which is the point. Scope to
// the hero section so these two tests are about the hero's own attribution.
const hero = (page: import("@playwright/test").Page) => page.getByRole("main").locator("section").first();

test("the primary hero CTA carries its attribution into registration", async ({ page }) => {
  await page.goto("/hu");

  await hero(page).getByRole("link", { name: "Kipróbálom 14 napig" }).click();

  await expect(page).toHaveURL(/\/register\?src=home-hero-primary$/);
});

test("the secondary hero CTA goes to the localized pricing path with its own slot", async ({
  page,
}) => {
  await page.goto("/hu");

  await hero(page).getByRole("link", { name: "Megnézem az árakat" }).click();

  await expect(page).toHaveURL(/\/hu\/arak\?src=home-hero-secondary$/);
});

test("an inbound utm campaign is stored as the first touch and never overwritten", async ({
  page,
  context,
}) => {
  await page.goto("/hu?utm_source=newsletter&utm_campaign=spring");

  const attribution = async () =>
    (await context.cookies()).find((c) => c.name === "lifey_attrib")?.value ?? "";

  expect(decodeURIComponent(await attribution())).toContain("utm_source=newsletter");

  // A later internal CTA must not replace the original touch (D-W8 is
  // first-touch, not last-touch).
  await page.goto("/hu/arak?src=pricing-pro");
  expect(decodeURIComponent(await attribution())).toContain("utm_source=newsletter");
});
