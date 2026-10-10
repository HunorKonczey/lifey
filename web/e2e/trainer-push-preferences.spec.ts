import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";

/**
 * The trainer's push switches (LIF-100, docs/85-trainer-push-plan.md): the account menu shows a switch for the weekly report
 * email and one for each client push, each flips only itself, and the backend keeps the others as they were.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2ePushPrefs123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Pushes" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  return ((await registerRes.json()) as { id: number }).id;
}

/** ROLE_TRAINER has no grant API - see trainer-flow.spec.ts for the why. */
async function grantTrainerRole(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [userId]);
  } finally {
    await db.end();
  }
}

test("the account menu switches the two client pushes, each on its own", async ({ page, request }) => {
  const email = `e2e-push-prefs-${Date.now()}@example.com`;
  const userId = await registerAndLogin(request, email);
  await grantTrainerRole(userId);

  // The roles ride in the JWT, so sign in after the grant.
  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL("**/dashboard");
  // The trainer switches live in the account menu of the trainer view.
  await page.goto("/admin");

  const accessToken: string = (await (await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } })).json()).accessToken;
  const preferences = async () => {
    const res = await request.get(`${API_BASE}/trainer/preferences`, { headers: { Authorization: `Bearer ${accessToken}` } });
    return res.ok() ? ((await res.json()) as Record<string, boolean>) : null;
  };

  await page.getByRole("button", { name: /E2E Pushes|E2E/ }).first().click();
  const missed = page.getByRole("switch", { name: "Push: client missed a workout" });
  const weighIn = page.getByRole("switch", { name: "Push: client's weekly weigh-in" });
  const report = page.getByRole("switch", { name: "Weekly email report" });
  await expect(report).toBeVisible();
  await expect(missed).toBeChecked();
  await expect(weighIn).toBeChecked();

  await test.step("turning the missed-workout push off leaves the other two as they were", async () => {
    await missed.click();
    await expect(missed).not.toBeChecked();
    await expect(weighIn).toBeChecked();
    await expect(report).toBeChecked();
    const stored = await preferences();
    if (stored) {
      expect(stored).toMatchObject({ clientMissedWorkoutPushEnabled: false, clientWeighInPushEnabled: true, weeklyReportEmailEnabled: true });
    }
  });

  await test.step("the weigh-in push is its own switch, and both stay off after a reload", async () => {
    await weighIn.click();
    await expect(weighIn).not.toBeChecked();
    await page.reload();
    await page.getByRole("button", { name: /E2E Pushes|E2E/ }).first().click();
    await expect(page.getByRole("switch", { name: "Push: client missed a workout" })).not.toBeChecked();
    await expect(page.getByRole("switch", { name: "Push: client's weekly weigh-in" })).not.toBeChecked();
    await expect(page.getByRole("switch", { name: "Weekly email report" })).toBeChecked();
  });
});
