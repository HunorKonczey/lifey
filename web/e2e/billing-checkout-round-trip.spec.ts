import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { Client } from "pg";

/**
 * The Prompt 6 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "Playwright with a stubbed checkout endpoint; assert the page never shows
 * the new plan before the entitlement response changes, and that the 30 s
 * timeout path renders." D-T3 (§3) is what's under test: the redirect back
 * from Stripe (`?checkout=success`) is never trusted on its own (64 D-B5) —
 * only a `GET /api/v1/me/entitlements` response that actually matches counts.
 *
 * `GET /api/v1/me/entitlements` is stubbed via `page.route()` so the test
 * controls exactly when (or whether) the "new" plan appears, without a real
 * Stripe webhook. `page.clock` fakes `setTimeout`/`Date` so the 30 s ceiling
 * doesn't mean a 30-real-second test — every other spec in this suite talks
 * to the real backend; this is the first to stub a response instead, exactly
 * because the whole point here is controlling *when* the backend "changes
 * its mind", which a real webhook-driven backend can't be told to do on a
 * schedule.
 *
 * Auth is seeded directly (a real access+refresh token pair from the real
 * backend, injected into localStorage before the page's own scripts run)
 * rather than driven through the login UI — faster, and avoids the login
 * page's own concerns entirely, which aren't what this test is about.
 *
 * Requires the real backend + Postgres running on localhost:8080/5432 (see
 * playwright.config.ts, which only auto-starts the Next.js dev server).
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = {
  host: "localhost",
  port: 5432,
  database: "lifey",
  user: "lifey",
  password: "lifey",
};

async function registerLoginAndGrantTrainer(request: APIRequestContext, email: string, password: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password, firstName: "E2E", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();

  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query(
      "insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing",
      [user.id],
    );
    await db.query(
      "insert into subscription (user_id, provider, status, plan, current_period_end, cancel_at_period_end, created_at, updated_at) " +
        "values ($1, 'STRIPE', 'ACTIVE', 'STARTER', now() + interval '20 days', false, now(), now())",
      [user.id],
    );
  } finally {
    await db.end();
  }

  // Re-login: the role/subscription were both added after this point, but
  // the entitlement resolver reads them fresh on every request regardless of
  // the JWT's own claims — only ROLE_TRAINER itself is JWT-cached, and it's
  // needed for AdminLayout's guard to let the test through to the page at all.
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  const tokens: { accessToken: string; refreshToken: string } = await loginRes.json();
  return tokens;
}

/** Seeds a logged-in session without driving the login UI, and stashes which plan the "checkout" was for. */
async function seedSession(page: Page, refreshToken: string, pendingPlan: string) {
  await page.addInitScript(
    ({ rt, plan }) => {
      localStorage.setItem("lifey-rt", rt);
      sessionStorage.setItem("lifey-billing-pending-plan", plan);
    },
    { rt: refreshToken, plan: pendingPlan },
  );
}

const OLD_ENTITLEMENT = {
  tier: "PRO",
  source: "STRIPE",
  adsEnabled: false,
  historyDays: null,
  aiCreditsRemaining: null,
  trainer: { plan: "STARTER", status: "ACTIVE", maxClients: 5, activeClients: 0, trialEndsAt: null },
  expiresAt: "2026-09-17T09:00:00Z",
  checkedAt: "2026-08-28T09:00:00Z",
  graceUntil: "2026-09-04T09:00:00Z",
  degraded: false,
};

const NEW_ENTITLEMENT = {
  ...OLD_ENTITLEMENT,
  trainer: { plan: "PRO", status: "ACTIVE", maxClients: 25, activeClients: 0, trialEndsAt: null },
};

test.describe("/admin/billing checkout round trip (D-T3)", () => {
  test("never shows the new plan before entitlements confirm it, then shows it once they do", async ({ page, request }) => {
    const email = `e2e-checkout-confirm-${Date.now()}@example.com`;
    const { refreshToken } = await registerLoginAndGrantTrainer(request, email, "E2eCheckout123!");
    await seedSession(page, refreshToken, "PRO");

    let entitlementCalls = 0;
    await page.route("**/api/v1/me/entitlements", async (route) => {
      if (route.request().method() === "OPTIONS") return route.continue();
      entitlementCalls += 1;
      // Confirms on the 3rd fetch (1 initial + 2 polls) — plenty of room to
      // assert the "still old" state in between.
      const body = entitlementCalls >= 3 ? NEW_ENTITLEMENT : OLD_ENTITLEMENT;
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(body) });
    });

    await page.clock.install();
    await page.goto("/admin/billing?checkout=success");

    await expect(page.getByTestId("checkout-activating-banner")).toBeVisible();
    // The stale/previous plan must not appear anywhere while polling — not
    // even the plan chooser's "Current plan" tag, which reads straight from
    // the same (still-old) entitlement.
    await expect(page.getByTestId("current-plan-name")).not.toBeVisible();
    await expect(page.getByText("Starter", { exact: true })).not.toBeVisible();

    // Tick through the 1s and 1s polls (checkoutPoll.ts's schedule) — still unconfirmed.
    await page.clock.fastForward(1000);
    await expect.poll(() => entitlementCalls).toBeGreaterThanOrEqual(2);
    await expect(page.getByTestId("checkout-activating-banner")).toBeVisible();
    await expect(page.getByTestId("current-plan-name")).not.toBeVisible();

    await page.clock.fastForward(1000);
    await expect.poll(() => entitlementCalls).toBeGreaterThanOrEqual(3);

    // Now confirmed: the banner is gone, and the new plan (and only the new one) shows.
    await expect(page.getByTestId("checkout-activating-banner")).not.toBeVisible();
    await expect(page.getByTestId("current-plan-name")).toHaveText("Pro");
    await expect(page.getByText("0 / 25 active clients")).toBeVisible();
  });

  test("shows the 30 s timeout state, with a working manual refresh, if entitlements never confirm", async ({ page, request }) => {
    const email = `e2e-checkout-timeout-${Date.now()}@example.com`;
    const { refreshToken } = await registerLoginAndGrantTrainer(request, email, "E2eCheckout123!");
    await seedSession(page, refreshToken, "PRO");

    let entitlementCalls = 0;
    await page.route("**/api/v1/me/entitlements", async (route) => {
      if (route.request().method() === "OPTIONS") return route.continue();
      entitlementCalls += 1;
      // Never confirms — the webhook that would flip this to PRO never lands.
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(OLD_ENTITLEMENT) });
    });

    await page.clock.install();
    await page.goto("/admin/billing?checkout=success");
    await expect(page.getByTestId("checkout-activating-banner")).toBeVisible();
    await expect.poll(() => entitlementCalls).toBeGreaterThanOrEqual(1);

    // checkoutPoll.ts's own schedule, stepped through exactly — each
    // fastForward is followed by waiting for the *next* real network call to
    // land before advancing the clock again. A single large fastForward can
    // fire several fake setTimeouts before any of their async refetch()es
    // actually resolve (a real Promise, tied to real time, not the fake
    // clock), so chained timers scheduled only after that await never get a
    // chance to become "due" within one atomic jump.
    const POLL_SCHEDULE_MS = [1000, 1000, 2000, 3000, 5000, 8000, 10000];
    for (let i = 0; i < POLL_SCHEDULE_MS.length; i++) {
      await page.clock.fastForward(POLL_SCHEDULE_MS[i]);
      // A generous timeout: under parallel-worker load the mocked fetch's
      // promise chain can take noticeably longer than the default 5s to
      // settle even though the fake clock jump itself is instant.
      await expect.poll(() => entitlementCalls, { timeout: 15_000 }).toBeGreaterThanOrEqual(i + 2);
    }

    await expect(page.getByTestId("checkout-timedout-banner")).toBeVisible();
    await expect(page.getByText("Still waiting on confirmation")).toBeVisible();
    // The stale plan is fine to show once timed out (66 D-T3: "the page says
    // so and offers a refresh") — it's showing what's already true, not a
    // premature new plan.
    await expect(page.getByTestId("current-plan-name")).toHaveText("Starter");

    const refreshButton = page.getByRole("button", { name: "Check again" });
    await expect(refreshButton).toBeEnabled();
    await refreshButton.click();
    // Still not confirmed (the stub never changes) — stays in the timed-out state, not stuck loading forever.
    await expect(refreshButton).toBeEnabled();
    await expect(page.getByTestId("checkout-timedout-banner")).toBeVisible();
  });

  test("?checkout=cancel shows a plain notice and never starts the confirmation poll", async ({ page, request }) => {
    const email = `e2e-checkout-cancel-${Date.now()}@example.com`;
    const { refreshToken } = await registerLoginAndGrantTrainer(request, email, "E2eCheckout123!");
    await seedSession(page, refreshToken, "PRO");

    await page.goto("/admin/billing?checkout=cancel");

    await expect(page.getByTestId("checkout-cancel-notice")).toBeVisible();
    await expect(page.getByTestId("checkout-activating-banner")).not.toBeVisible();
    await expect(page.getByTestId("current-plan-name")).toHaveText("Starter");
    await expect(page).toHaveURL(/\/admin\/billing$/);
  });
});
