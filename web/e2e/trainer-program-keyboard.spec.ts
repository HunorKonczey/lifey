import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";

/**
 * Program editor from the keyboard (docs/redesign-web/78 W8.5, LIF-96): pick a template in the rail with Space, Tab to a
 * week-grid cell, Enter places it; Enter on a filled cell opens its slot dialog, Escape closes it. Real key events, no
 * pointer anywhere. Not asserted, because they are known gaps: the drag grip's own keyboard drag (LIF-136) and focus
 * returning to the cell after the slot dialog closes (LIF-137).
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };

async function registerAndLogin(request: APIRequestContext, email: string, password: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password, firstName: "E2E", lastName: "Keyboard" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();
  return user.id;
}

async function login(request: APIRequestContext, email: string, password: string) {
  const res = await request.post(`${API_BASE}/auth/login`, { data: { email, password } });
  expect(res.ok(), await res.text()).toBeTruthy();
  return (await res.json()).accessToken as string;
}

/** ROLE_TRAINER has no grant API — see trainer-flow.spec.ts for the why. */
async function grantTrainerRole(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [userId]);
  } finally {
    await db.end();
  }
}

test.describe("Program editor keyboard", () => {
  test("Space picks a template, Tab reaches a cell, Enter places it; Enter on a filled cell opens the slot dialog", async ({ page, request }) => {
    const runId = Date.now();
    const email = `e2e-kbd-trainer-${runId}@example.com`;
    const password = "E2eTrainer123!";
    const templateName = `Felső ${runId}`;

    await test.step("a trainer with one template", async () => {
      const userId = await registerAndLogin(request, email, password);
      await grantTrainerRole(userId);
      // The pre-grant token's `roles` claim is stale — log in again after the grant.
      const token = await login(request, email, password);
      const headers = { Authorization: `Bearer ${token}` };
      const exRes = await request.post(`${API_BASE}/exercises`, { headers, data: { name: `Fekvenyomás ${runId}`, category: "CHEST", equipment: "BARBELL", defaultRestSeconds: 90 } });
      expect(exRes.ok(), await exRes.text()).toBeTruthy();
      const exercise: { id: number } = await exRes.json();
      const tplRes = await request.post(`${API_BASE}/workout-templates`, { headers, data: { name: templateName, exercises: [{ exerciseId: exercise.id, targetSets: 3 }] } });
      expect(tplRes.ok(), await tplRes.text()).toBeTruthy();
    });

    await test.step("sign in through the UI and open a new program", async () => {
      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(email);
      await page.getByPlaceholder("••••••••").fill(password);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL(/dashboard|admin/);
      await page.goto("/admin/programs/new");
    });

    const row = page.getByTestId("program-rail-template").filter({ hasText: templateName });
    const summary = page.getByText(/\d+ weeks? · \d+ workouts?/).first();

    await test.step("Space picks the template", async () => {
      await row.focus();
      await page.keyboard.press("Space");
      await expect(row).toHaveAttribute("aria-pressed", "true");
    });

    await test.step("Tab leads to the first cell and Enter places the template there", async () => {
      const firstCell = page.getByRole("button", { name: /Week 1, Mon: Place/ });
      for (let i = 0; i < 12 && !(await firstCell.evaluate((el) => el === document.activeElement)); i++) await page.keyboard.press("Tab");
      await expect(firstCell).toBeFocused();
      await page.keyboard.press("Enter");
      await expect(page.getByRole("button", { name: `Week 1, Mon: ${templateName}` })).toBeVisible();
      await expect(summary).toContainText("1 workout");
    });

    await test.step("the picked template stays picked: Tab + Enter places a second one", async () => {
      await page.keyboard.press("Tab");
      await page.keyboard.press("Enter");
      await expect(summary).toContainText("2 workouts");
    });

    await test.step("with nothing picked, Enter on a filled cell opens its slot dialog and Escape closes it", async () => {
      await row.focus();
      await page.keyboard.press("Space");
      await expect(row).toHaveAttribute("aria-pressed", "false");
      const filled = page.getByRole("button", { name: `Week 1, Mon: ${templateName}` });
      await filled.focus();
      await page.keyboard.press("Enter");
      await expect(page.getByRole("dialog")).toBeVisible();
      await page.keyboard.press("Escape");
      await expect(page.getByRole("dialog")).toHaveCount(0);
    });
  });
});
