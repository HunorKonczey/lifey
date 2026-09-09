import { test, expect, type Page } from "@playwright/test";

/**
 * The signed-in states of the marketing tree (docs/landing_page/65 §10 edge
 * cases 1–2, 72 Prompt 5) — the header swapping to "back to app", and every
 * pricing CTA becoming "manage plan" pointing at `/admin/billing` instead of
 * offering a second signup.
 *
 * `e2e/pricing-page.spec.ts` deliberately skipped this when it was written,
 * because it needs a session and `/admin/billing` did not exist yet. Both are
 * now testable without a backend: `useSessionStore.initialize()` reads one
 * `localStorage` key and exchanges it at `POST /auth/refresh`, so seeding the
 * key and stubbing that one endpoint is a complete signed-in session as far as
 * these components are concerned. The rest of the app is untouched by this.
 */

function fakeAccessToken(): string {
  const claims = {
    sub: "42",
    email: "edzo@example.com",
    firstName: "Kis",
    lastName: "Pista",
    roles: ["ROLE_USER", "ROLE_TRAINER"],
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 3600,
  };
  const part = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");
  return `${part({ alg: "HS256", typ: "JWT" })}.${part(claims)}.signature`;
}

async function signIn(page: Page) {
  await page.addInitScript(() => {
    localStorage.setItem("lifey-rt", "fake-refresh-token");
  });
  await page.route("**/auth/refresh", (route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        accessToken: fakeAccessToken(),
        refreshToken: "fake-refresh-token-2",
      }),
    })
  );
}

test("the header swaps the trial CTA for a way back into the app", async ({ page }) => {
  await signIn(page);
  await page.goto("/hu");

  const backToApp = page.getByRole("banner").getByRole("link", { name: /Vissza az appba/ });
  await expect(backToApp).toBeVisible();
  await expect(page.getByRole("banner").getByRole("link", { name: "14 nap ingyen" })).toHaveCount(0);
  // The initials avatar is derived from the token's own claims.
  await expect(page.getByRole("banner").getByText("KP", { exact: true })).toBeVisible();

  await backToApp.click();
  await expect(page).toHaveURL(/\/dashboard$/);
});

test("every pricing card offers plan management instead of a second signup", async ({ page }) => {
  await signIn(page);
  await page.goto("/hu/arak");

  // Four, not three: the three plan cards plus `ManagePlanNotice`'s own
  // button, which points at the same place in both signed-in and signed-out
  // states.
  const manage = page.getByRole("main").locator('a[href="/admin/billing"]');
  await expect(manage).toHaveCount(4);
  await expect(page.getByRole("main").getByRole("link", { name: "Csomagválasztás" })).toHaveCount(0);

  await manage.first().click();
  await expect(page).toHaveURL(/\/admin\/billing$/);
});

test("a signed-out visitor still gets the signup CTAs", async ({ page }) => {
  await page.goto("/hu/arak");

  const signup = page.getByRole("main").getByRole("link", { name: "Csomagválasztás" });
  await expect(signup).toHaveCount(3);
  // Each card carries its own `?src=` slot so the pricing page can tell which
  // tier a signup came from (65 §7).
  await expect(signup.first()).toHaveAttribute("href", "/register?src=pricing-starter");
  await expect(page.getByRole("main").locator('a[href="/admin/billing"]')).toHaveCount(1);
});
