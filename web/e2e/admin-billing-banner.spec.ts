import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { Client } from "pg";

/**
 * The Prompt 7 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "a component test over every row of the table, asserting exactly one banner
 * and the correct dismissibility; plus a test that `> 7 days trial` renders
 * nothing." This project's Vitest config has no component-rendering
 * infrastructure (see `bannerState.test.ts`, which covers the table itself as
 * a pure function), so the *rendered* half of that Verify line — exactly one
 * banner, wired into the real admin layout, with dismissibility that survives
 * navigation, and D-T6's chat exemption — is what this file covers instead:
 * real trainer accounts, real subscription rows, driven through the real UI.
 *
 * Same conventions as `trainer-billing-page.spec.ts`: self-contained accounts,
 * ROLE_TRAINER granted via a direct DB write, `loginThroughUi` rather than
 * localStorage token injection (a real login avoids every race between
 * `useSessionStore.initialize()` call sites — the admin layout, the
 * superadmin layout, and the marketing header all call it independently —
 * and a manually-seeded, single-use refresh token).
 *
 * Requires the real backend + Postgres running on localhost:8080/5432 (see
 * playwright.config.ts, which only auto-starts the Next.js dev server).
 *
 * Requires the backend started with `BILLING_ENABLED=true`, unlike every
 * other spec in this suite. `lifey.billing.enabled=false` is this codebase's
 * deliberate rollback switch (64 §1 point 6): while it's off (the default in
 * every environment today, including a plain local run), `EntitlementService`
 * fails *open* for everyone — every response resolves to `source: "COMP"`
 * regardless of the underlying subscription row, and `SeatLimitServiceImpl`
 * lets every seat check pass. `bannerStateFor` (`bannerState.ts`) treats that
 * exact `source: "COMP"` signal as "nothing is actually enforced right now,
 * so don't claim otherwise" (66 §8 edge case 6 names the narrower super-admin
 * case, but the backend deliberately reuses the same source value for both —
 * see `EntitlementServiceImpl.openResponse`'s own comment: "open for
 * everyone, nothing degraded"). So with billing disabled, every row of D-T4's
 * table would be true-but-misleading — a "Your workspace is read-only" banner
 * while every action still actually works is worse than no banner. Each test
 * below probes the real state via `billingIsEnabled` and skips itself
 * (not fails) when it's off, the same category of environment gap as Prompt
 * 5's un-testable live-Stripe-checkout limitation.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2eBanner123!";

/** True only when the backend actually resolves a fresh, role-less user to FREE/NONE rather than the disabled-billing open COMP response. */
async function billingIsEnabled(request: APIRequestContext): Promise<boolean> {
  const email = `e2e-banner-probe-${Date.now()}@example.com`;
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password: PASSWORD, firstName: "Probe", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  const { accessToken } = await loginRes.json();
  const entRes = await request.get(`${API_BASE}/me/entitlements`, { headers: { Authorization: `Bearer ${accessToken}` } });
  const entitlement: { source: string } = await entRes.json();
  return entitlement.source === "NONE";
}

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password: PASSWORD, firstName: "E2E", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();
  return { userId: user.id };
}

async function grantTrainerRole(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [userId]);
  } finally {
    await db.end();
  }
}

type SeedState =
  | { status: "CANCELED" | "PAST_DUE" | "ACTIVE"; plan: "STARTER" | "PRO"; periodEndDays: number }
  | { status: "TRIALING"; plan: "STARTER" | "PRO"; trialDays: number };

async function seedSubscription(userId: number, state: SeedState) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    if (state.status === "TRIALING") {
      await db.query(
        "insert into subscription (user_id, provider, status, plan, trial_ends_at, cancel_at_period_end, created_at, updated_at) " +
          "values ($1, 'STRIPE', 'TRIALING', $2, now() + ($3 || ' days')::interval, false, now(), now())",
        [userId, state.plan, state.trialDays],
      );
    } else {
      await db.query(
        "insert into subscription (user_id, provider, status, plan, current_period_end, cancel_at_period_end, created_at, updated_at) " +
          "values ($1, 'STRIPE', $2, $3, now() + ($4 || ' days')::interval, false, now(), now())",
        [userId, state.status, state.plan, state.periodEndDays],
      );
    }
  } finally {
    await db.end();
  }
}

/** Seeds enough ACTIVE trainer_clients rows to push a trainer over a STARTER plan's 5-seat limit. */
async function seedActiveClientsOverLimit(request: APIRequestContext, trainerId: number, count: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    for (let i = 0; i < count; i++) {
      const res = await request.post(`${API_BASE}/auth/register`, {
        data: { email: `e2e-banner-client-${Date.now()}-${i}@example.com`, password: PASSWORD, firstName: "Client", lastName: `${i}` },
      });
      expect(res.ok(), await res.text()).toBeTruthy();
      const client: { id: number } = await res.json();
      await db.query(
        "insert into trainer_clients (trainer_id, client_id, status, expires_at, responded_at) " +
          "values ($1, $2, 'ACTIVE', now() + interval '1 day', now())",
        [trainerId, client.id],
      );
    }
  } finally {
    await db.end();
  }
}

async function loginThroughUi(page: Page, email: string) {
  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL("**/dashboard");
}

const banner = (page: Page) => page.getByTestId("admin-billing-banner");

test.describe("AdminBillingBanner (D-T4)", () => {
  test("CANCELED renders the non-dismissible, error-toned 'restricted' banner", async ({ page, request }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");
    const email = `e2e-banner-restricted-${Date.now()}@example.com`;
    const { userId } = await registerAndLogin(request, email);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "CANCELED", plan: "STARTER", periodEndDays: -5 });

    await loginThroughUi(page, email);
    await page.goto("/admin");

    await expect(banner(page)).toBeVisible();
    await expect(banner(page)).toHaveAttribute("data-banner-kind", "restricted");
    await expect(page.getByText("Your workspace is read-only")).toBeVisible();
    await expect(banner(page).getByRole("button")).toHaveCount(0);
  });

  test("PAST_DUE renders the non-dismissible 'pastDue' banner", async ({ page, request }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");
    const email = `e2e-banner-pastdue-${Date.now()}@example.com`;
    const { userId } = await registerAndLogin(request, email);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "PAST_DUE", plan: "PRO", periodEndDays: 20 });

    await loginThroughUi(page, email);
    await page.goto("/admin");

    await expect(banner(page)).toHaveAttribute("data-banner-kind", "pastDue");
    await expect(page.getByText("We couldn't charge your card")).toBeVisible();
    await expect(banner(page).getByRole("button")).toHaveCount(0);
  });

  test("ACTIVE over the seat limit renders the 'overLimit' banner with the actual counts", async ({ page, request }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");
    const email = `e2e-banner-overlimit-${Date.now()}@example.com`;
    const { userId } = await registerAndLogin(request, email);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "ACTIVE", plan: "STARTER", periodEndDays: 20 });
    await seedActiveClientsOverLimit(request, userId, 6); // STARTER's limit is 5

    await loginThroughUi(page, email);
    await page.goto("/admin");

    await expect(banner(page)).toHaveAttribute("data-banner-kind", "overLimit");
    await expect(page.getByText("6 / 5 active clients")).toBeVisible();
    await expect(banner(page).getByRole("button")).toHaveCount(0);
  });

  test("TRIALING with <= 3 days left renders the non-dismissible 'trialUrgent' banner", async ({ page, request }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");
    const email = `e2e-banner-trialurgent-${Date.now()}@example.com`;
    const { userId } = await registerAndLogin(request, email);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "TRIALING", plan: "PRO", trialDays: 2 });

    await loginThroughUi(page, email);
    await page.goto("/admin");

    await expect(banner(page)).toHaveAttribute("data-banner-kind", "trialUrgent");
    await expect(page.getByText("2 days left", { exact: true })).toBeVisible();
    await expect(banner(page).getByRole("button")).toHaveCount(0);
  });

  test("TRIALING with 4-7 days left renders the dismissible 'trialInfo' banner, and dismissal survives navigation for the rest of the session", async ({
    page,
    request,
  }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");
    const email = `e2e-banner-trialinfo-${Date.now()}@example.com`;
    const { userId } = await registerAndLogin(request, email);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "TRIALING", plan: "PRO", trialDays: 6 });

    await loginThroughUi(page, email);
    await page.goto("/admin");

    await expect(banner(page)).toHaveAttribute("data-banner-kind", "trialInfo");
    await expect(page.getByText("6 days left in your trial")).toBeVisible();

    await banner(page).getByRole("button", { name: "Dismiss" }).click();
    await expect(banner(page)).not.toBeVisible();

    // Still dismissed after a client-side navigation elsewhere in the shell —
    // "dismissible, for the session" (D-T4), not just for the current page.
    await page.getByRole("link", { name: "Calendar" }).click();
    await page.waitForURL("**/admin/calendar");
    await expect(banner(page)).not.toBeVisible();
  });

  test("TRIALING with > 7 days left renders no banner — silence in the first week is deliberate", async ({ page, request }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");
    const email = `e2e-banner-trialquiet-${Date.now()}@example.com`;
    const { userId } = await registerAndLogin(request, email);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "TRIALING", plan: "PRO", trialDays: 10 });

    await loginThroughUi(page, email);
    await page.goto("/admin");

    await expect(banner(page)).not.toBeVisible();
  });

  test("D-T6: the banner never appears on /admin/chat, even for an otherwise-restricted trainer", async ({ page, request }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");
    const email = `e2e-banner-chatexempt-${Date.now()}@example.com`;
    const { userId } = await registerAndLogin(request, email);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "CANCELED", plan: "STARTER", periodEndDays: -5 });

    await loginThroughUi(page, email);
    await page.goto("/admin");
    await expect(banner(page)).toBeVisible();

    await page.goto("/admin/chat");
    await expect(banner(page)).not.toBeVisible();

    // And it's back the moment they leave chat — this is chat's exemption, not a global dismissal.
    await page.goto("/admin");
    await expect(banner(page)).toBeVisible();
  });
});
