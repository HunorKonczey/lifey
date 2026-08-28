import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";

/**
 * The Prompt 5 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "Playwright over three seeded states (trialing, active-Starter, past-due)."
 * Same conventions as e2e/trainer-flow.spec.ts — fully self-contained accounts,
 * ROLE_TRAINER granted via a direct DB write (no grant API by design). The
 * `subscription` row itself is also seeded directly rather than through a real
 * Stripe checkout, which this environment has no test credentials for — the
 * one manual-only gap this suite can't close (see the prompt's own landed notes).
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

async function registerAndLogin(request: APIRequestContext, email: string, password: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password, firstName: "E2E", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();

  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();

  return { userId: user.id };
}

async function grantTrainerRole(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query(
      "insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing",
      [userId],
    );
  } finally {
    await db.end();
  }
}

type SeedState =
  | { status: "TRIALING"; plan: "PRO"; trialDays: number }
  | { status: "ACTIVE"; plan: "STARTER"; periodEndDays: number }
  | { status: "PAST_DUE"; plan: "PRO"; periodEndDays: number };

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

async function loginThroughUi(page: import("@playwright/test").Page, email: string, password: string) {
  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL("**/dashboard");
}

test.describe("/admin/billing", () => {
  test("a TRIALING trainer sees their trial status, days left, and PRO marked as current", async ({ page, request }) => {
    const email = `e2e-billing-trial-${Date.now()}@example.com`;
    const password = "E2eBilling123!";
    const { userId } = await registerAndLogin(request, email, password);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "TRIALING", plan: "PRO", trialDays: 6 });

    await loginThroughUi(page, email, password);
    await page.goto("/admin/billing");

    await expect(page.getByText("Trial · 6 days left")).toBeVisible();
    await expect(page.getByText(/Your trial ends on/)).toBeVisible();
    const proCard = page.locator('[data-testid="plan-chooser-card"][data-plan="pro"]');
    await expect(proCard.getByText("Current plan")).toBeVisible();
  });

  test("an ACTIVE Starter trainer sees Active status and Starter marked as current", async ({ page, request }) => {
    const email = `e2e-billing-active-${Date.now()}@example.com`;
    const password = "E2eBilling123!";
    const { userId } = await registerAndLogin(request, email, password);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "ACTIVE", plan: "STARTER", periodEndDays: 20 });

    await loginThroughUi(page, email, password);
    await page.goto("/admin/billing");

    await expect(page.getByText("Active", { exact: true })).toBeVisible();
    const starterCard = page.locator('[data-testid="plan-chooser-card"][data-plan="starter"]');
    await expect(starterCard.getByText("Current plan")).toBeVisible();
    await expect(page.getByText("0 / 5 active clients")).toBeVisible();
  });

  test("a PAST_DUE trainer sees the 'Payment failed' status pill", async ({ page, request }) => {
    const email = `e2e-billing-pastdue-${Date.now()}@example.com`;
    const password = "E2eBilling123!";
    const { userId } = await registerAndLogin(request, email, password);
    await grantTrainerRole(userId);
    await seedSubscription(userId, { status: "PAST_DUE", plan: "PRO", periodEndDays: 3 });

    await loginThroughUi(page, email, password);
    await page.goto("/admin/billing");

    await expect(page.getByText("Payment failed")).toBeVisible();
    const proCard = page.locator('[data-testid="plan-chooser-card"][data-plan="pro"]');
    await expect(proCard.getByText("Current plan")).toBeVisible();
    await expect(page.getByText("0 / 25 active clients")).toBeVisible();
  });
});
