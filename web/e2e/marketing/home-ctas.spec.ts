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
    decodeURIComponent(
      (await context.cookies()).find((c) => c.name === "lifey_attrib")?.value ?? ""
    );

  // `src/proxy.ts` sets this on the navigation's own response, so it is
  // already there — polling rather than reading once keeps the test honest
  // about AttributionCapture.tsx's fallback effect too, which only lands
  // after hydration.
  await expect.poll(attribution).toContain("utm_source=newsletter");

  // A later internal CTA must not replace the original touch (D-W8 is
  // first-touch, not last-touch).
  await page.goto("/hu/arak?src=pricing-pro");

  // Driving a hydrated control first: an overwrite could only come from this
  // page's own effect, so asserting before hydration would pass for the wrong
  // reason. The interval toggle only answers once the client bundle is live.
  await page.getByRole("button", { name: "Havi" }).click();
  await expect(page.getByText("4990 Ft", { exact: false }).first()).toBeVisible();

  expect(await attribution()).toContain("utm_source=newsletter");
});

/**
 * The point of writing the cookie in the proxy rather than only in a client
 * effect: the visitor who bounces before hydration. Disabling JS is the only
 * way to assert that from the outside — with the bundle running, a passing
 * read can't tell the two writers apart.
 */
test.describe("with no client JS", () => {
  test.use({ javaScriptEnabled: false });

  test("the first touch is captured on the server, on the first response", async ({
    page,
    context,
  }) => {
    await page.goto("/hu?utm_source=newsletter&utm_campaign=spring");

    const cookie = (await context.cookies()).find((c) => c.name === "lifey_attrib");
    expect(decodeURIComponent(cookie?.value ?? "")).toContain("utm_source=newsletter");
  });

  test("the locale redirect from / carries the campaign through", async ({ page, context }) => {
    await page.goto("/?utm_source=newsletter");

    // /en, not /hu: playwright.config.ts pins the browser to en-US, so this
    // is the negotiated locale — the point here is the campaign surviving
    // the redirect, whichever locale it lands on.
    await expect(page).toHaveURL(/\/en\?utm_source=newsletter$/);
    const cookie = (await context.cookies()).find((c) => c.name === "lifey_attrib");
    expect(decodeURIComponent(cookie?.value ?? "")).toContain("utm_source=newsletter");
  });
});
