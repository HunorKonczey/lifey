import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";

/**
 * The Prompt 2 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "a fresh non-trainer user is routed to /admin/pending, sees the pending
 * state, and after an approval (seeded in the test DB) is routed into
 * /admin." Same conventions as e2e/trainer-flow.spec.ts — fully self-contained
 * accounts, direct-DB approval since Prompt 3's superadmin queue UI doesn't
 * exist yet (mirrors exactly what RoleManagementServiceImpl.grant +
 * TrainerRequestResolutionListener do together on a real approval).
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
  const { accessToken }: { accessToken: string } = await loginRes.json();

  return { userId: user.id, accessToken };
}

/** Grants ROLE_TRAINER and resolves the PENDING request, directly in Postgres —
 *  simulating the superadmin approve action (66 Prompt 3, not yet built). */
async function approveTrainerRequest(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query(
      "insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing",
      [userId],
    );
    await db.query(
      "update trainer_request set status = 'APPROVED', decided_at = now(), decided_by = $1 " +
        "where user_id = $1 and status = 'PENDING'",
      [userId],
    );
  } finally {
    await db.end();
  }
}

test.describe("Trainer access request flow", () => {
  test("the for-trainers CTA routes a visitor into the trainer-request flow", async ({ page }) => {
    // The default (unprefixed) locale is Hungarian — the deterministic English
    // config only sets the browser's Accept-Language, not next-intl's routing.
    await page.goto("/en/for-trainers");
    await page.getByRole("link", { name: "Request access" }).click();
    await expect(page).toHaveURL(/\/register\?.*next=(%2Fadmin%2Fpending|\/admin\/pending)/);
  });

  test("fresh user submits a request, waits, and is routed into /admin once approved", async ({ page, request }) => {
    const runId = Date.now();
    const email = `e2e-trainer-request-${runId}@example.com`;
    const password = "E2eTrainerReq123!";

    const { userId } = await test.step("register a fresh ROLE_USER account", async () => {
      return registerAndLogin(request, email, password);
    });

    await test.step("log in through the real UI, then open /admin/pending", async () => {
      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(email);
      await page.getByPlaceholder("••••••••").fill(password);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL("**/dashboard");

      await page.goto("/admin/pending");
      await expect(page).toHaveURL(/\/admin\/pending$/);
    });

    await test.step("no request yet: the page shows the request form", async () => {
      await expect(page.getByRole("heading", { name: "Become a Lifey trainer" })).toBeVisible();
    });

    await test.step("submitting the form transitions to the pending/waiting state", async () => {
      await page.getByPlaceholder(/spreadsheets/).fill("I coach 12 people on strength training");
      await page.getByPlaceholder("15", { exact: true }).fill("12");
      await page.getByRole("button", { name: "Submit request" }).click();
      await expect(page.getByText("We're reviewing your application")).toBeVisible();
    });

    await test.step("a direct DB approval (simulating the superadmin queue) is picked up by the poll", async () => {
      await approveTrainerRequest(userId);
      // The page polls /trainer-requests/me every 10s and, on APPROVED,
      // refreshes the JWT before redirecting — comfortably inside 30s.
      await page.waitForURL("**/admin", { timeout: 30_000 });
    });
  });
});
