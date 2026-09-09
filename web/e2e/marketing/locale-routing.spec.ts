import { test, expect } from "@playwright/test";

/**
 * Locale routing (docs/landing_page/65 §3, §10 and 72 Prompt 5) — the proxy's
 * negotiation on `/`, the language switch keeping the current page, the
 * cross-locale path being a real 404, and the one thing the proxy must never
 * touch: the authenticated app.
 */

test.describe("locale negotiation on /", () => {
  test.describe("a Hungarian visitor", () => {
    test.use({ locale: "hu-HU" });

    test("lands on /hu", async ({ page }) => {
      await page.goto("/");
      await expect(page).toHaveURL(/\/hu$/);
    });
  });

  test.describe("an English visitor", () => {
    test.use({ locale: "en-US" });

    test("lands on /en", async ({ page }) => {
      await page.goto("/");
      await expect(page).toHaveURL(/\/en$/);
    });
  });

  test.describe("a visitor with an unsupported language", () => {
    test.use({ locale: "de-DE" });

    test("falls back to the default locale, not to a /de prefix", async ({ page }) => {
      await page.goto("/");
      await expect(page).toHaveURL(/\/hu$/);
    });
  });
});

test("the language switch preserves the current page, not just the locale", async ({ page }) => {
  await page.goto("/hu/edzoknek");

  await page.locator("#site-footer").getByRole("link", { name: "EN", exact: true }).click();

  // The localized pathname for the same route key — not /en, and not /en/edzoknek.
  await expect(page).toHaveURL(/\/en\/for-trainers$/);

  await page.locator("#site-footer").getByRole("link", { name: "HU", exact: true }).click();
  await expect(page).toHaveURL(/\/hu\/edzoknek$/);
});

test("a cross-locale path redirects to its canonical form instead of answering twice", async ({
  request,
}) => {
  // 65 §10 edge case 7 predicted a 404 here ("a crawler on /en/arak → 404").
  // The shipped behaviour is a 307 to the canonical localized path, which is
  // what next-intl's `pathnames` map does — and it is the better answer: the
  // requirement behind that line is that one piece of content never answers at
  // two URLs, which a redirect satisfies while also keeping the link usable.
  // Recorded as a correction in docs/landing_page/72 §3.1 (W14) rather than
  // "fixed" into a 404.
  for (const [wrong, canonical] of [
    ["/en/arak", "/en/pricing"],
    ["/hu/pricing", "/hu/arak"],
    ["/en/edzoknek", "/en/for-trainers"],
  ] as const) {
    const response = await request.get(wrong, { maxRedirects: 0 });
    expect(response.status(), `${wrong} must not answer 200`).toBe(307);
    expect(response.headers()["location"]).toContain(canonical);
  }
});

test("the proxy never touches the authenticated app", async ({ request }) => {
  // Checked at the request level on purpose: `/dashboard` is client-side
  // guarded, so a browser navigation would end on /login for its own reasons
  // and prove nothing about the proxy. What matters is that no locale
  // redirect is issued for it (65 §14 risk 1, proxy.test.ts's runtime twin).
  for (const path of ["/dashboard", "/login", "/admin/billing", "/onboarding"]) {
    const response = await request.get(path, { maxRedirects: 0 });
    const location = response.headers()["location"] ?? "";
    expect(location, `${path} must not be locale-redirected`).not.toMatch(/^\/(hu|en)\//);
  }
});
