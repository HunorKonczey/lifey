import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { Client } from "pg";

/**
 * The Prompt 8 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "Playwright over a seeded CANCELED trainer: each of the four shows the
 * dialog, and /admin/chat is fully usable (D-T6)." The four are D-T5's own
 * list: send invite, assign content, assign a program, schedule a workout —
 * `BillingBlockedDialog` (`features/billing/components/BillingBlockedDialog.tsx`)
 * is the one shared component all four render instead of their normal flow
 * when `useTrainerBillingGate()` (`features/billing/hooks.ts`) reports
 * anything but `"OK"`.
 *
 * Same conventions as `admin-billing-banner.spec.ts`: self-contained
 * accounts, `loginThroughUi` (not localStorage token seeding — see that
 * file's header for why), and requires the backend started with
 * `BILLING_ENABLED=true` for the same reason as the banner spec — with
 * billing disabled (this project's default everywhere), every entitlement
 * resolves to `source: "COMP"` and `trainerBillingStateFor` correctly
 * reports `"OK"` for everyone (`billingGate.ts`'s own landed comment).
 * `billingIsEnabled` probes the real state and skips rather than fails when
 * it's off.
 *
 * Requires the real backend + Postgres running on localhost:8080/5432 (see
 * playwright.config.ts, which only auto-starts the Next.js dev server).
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2eBlocked123!";

async function billingIsEnabled(request: APIRequestContext): Promise<boolean> {
  const email = `e2e-blocked-probe-${Date.now()}@example.com`;
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

async function register(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password: PASSWORD, firstName: "E2E", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();
  return user.id;
}

async function grantTrainerRoleAndCancel(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [userId]);
    await db.query(
      "insert into subscription (user_id, provider, status, plan, current_period_end, cancel_at_period_end, created_at, updated_at) " +
        "values ($1, 'STRIPE', 'CANCELED', 'STARTER', now() - interval '5 days', false, now(), now())",
      [userId],
    );
  } finally {
    await db.end();
  }
}

/** Logged in only after the role grant — the JWT's `roles` claim is fixed at
 *  mint time, so an API call as a trainer needs a token minted after grant. */
async function login(request: APIRequestContext, email: string): Promise<string> {
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  const { accessToken }: { accessToken: string } = await loginRes.json();
  return accessToken;
}

/** One workout template and one program, so the assign-content and assign-program triggers have a row to click. */
async function seedTemplateAndProgram(request: APIRequestContext, accessToken: string) {
  const headers = { Authorization: `Bearer ${accessToken}` };

  const exercisesRes = await request.get(`${API_BASE}/exercises`, { headers });
  expect(exercisesRes.ok(), await exercisesRes.text()).toBeTruthy();
  const exercises: Array<{ id: number }> = await exercisesRes.json();
  expect(exercises.length).toBeGreaterThan(0);

  const templateRes = await request.post(`${API_BASE}/workout-templates`, {
    headers,
    data: { name: `E2E Blocked Template ${Date.now()}`, exercises: [{ exerciseId: exercises[0].id, targetSets: 3 }] },
  });
  expect(templateRes.ok(), await templateRes.text()).toBeTruthy();
  const template: { id: number } = await templateRes.json();

  const programRes = await request.post(`${API_BASE}/trainer/programs`, {
    headers,
    data: {
      name: `E2E Blocked Program ${Date.now()}`,
      weeksCount: 1,
      workouts: [{ weekNumber: 1, dayOfWeek: "MONDAY", templateId: template.id, timeOfDay: null, note: null }],
    },
  });
  expect(programRes.ok(), await programRes.text()).toBeTruthy();
}

async function loginThroughUi(page: Page, email: string) {
  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL("**/dashboard");
}

const blockedDialog = (page: Page) => page.getByTestId("billing-blocked-dialog");

test.describe("BillingBlockedDialog (D-T5)", () => {
  test("a CANCELED trainer sees the blocked dialog, not the normal flow, on all four gated actions", async ({
    page,
    request,
  }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");

    const email = `e2e-blocked-all-${Date.now()}@example.com`;
    const userId = await register(request, email);
    await grantTrainerRoleAndCancel(userId);
    const accessToken = await login(request, email);
    await seedTemplateAndProgram(request, accessToken);

    await loginThroughUi(page, email);

    await test.step("send invite", async () => {
      await page.goto("/admin/invites");
      await page.getByPlaceholder("client@example.com").fill(`e2e-blocked-target-${Date.now()}@example.com`);
      await page.getByRole("button", { name: "Invite" }).click();
      await expect(blockedDialog(page)).toBeVisible();
      await expect(blockedDialog(page)).toHaveAttribute("data-blocked-reason", "restricted");
      await expect(page.getByRole("dialog").getByText("Your workspace is read-only")).toBeVisible();
    });

    await test.step("assign content (a workout template)", async () => {
      await page.goto("/admin/workouts");
      await page.getByTestId("assign-template").first().click();
      await expect(blockedDialog(page)).toBeVisible();
      await expect(blockedDialog(page)).toHaveAttribute("data-blocked-reason", "restricted");
      // The normal drawer never mounted — no client roster, no "Assign" submit button from it.
      await expect(page.getByTestId("assign-to-client-drawer")).toHaveCount(0);
    });

    await test.step("assign a program", async () => {
      await page.goto("/admin/programs");
      await page.getByTestId("program-assign-button").first().click();
      await expect(blockedDialog(page)).toBeVisible();
      await expect(blockedDialog(page)).toHaveAttribute("data-blocked-reason", "restricted");
      await expect(page.getByTestId("assign-program-drawer")).toHaveCount(0);
    });

    await test.step("schedule a workout", async () => {
      await page.goto("/admin/calendar");
      await page.getByRole("button", { name: "Schedule workout" }).click();
      await expect(blockedDialog(page)).toBeVisible();
      await expect(blockedDialog(page)).toHaveAttribute("data-blocked-reason", "restricted");
      await expect(page.getByTestId("schedule-workout-drawer")).toHaveCount(0);
    });
  });

  test("D-T6: /admin/chat stays fully usable for the same CANCELED trainer", async ({ page, request }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");

    const email = `e2e-blocked-chat-${Date.now()}@example.com`;
    const userId = await register(request, email);
    await grantTrainerRoleAndCancel(userId);

    await loginThroughUi(page, email);
    await page.goto("/admin/chat");

    await expect(page.getByText("Pick a conversation")).toBeVisible();
    await expect(blockedDialog(page)).not.toBeVisible();
    await expect(page.getByTestId("admin-billing-banner")).not.toBeVisible();
  });
});
