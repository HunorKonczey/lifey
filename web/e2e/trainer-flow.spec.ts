import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";

/**
 * End-to-end trainer flow (docs/personal_trainer/07-utemterv-es-kockazatok.md,
 * PT4 item 19): invite -> accept (API-simulated, no mobile app here) -> assign
 * -> the client shows up in the trainer's client stats/detail view.
 *
 * Fully self-contained — every account and every piece of content this test
 * needs, it creates itself:
 *  - trainer + client are freshly registered accounts (unique email per run)
 *  - ROLE_TRAINER has no grant API (by design — only ROLE_SUPER_ADMIN can grant
 *    it, and ROLE_SUPER_ADMIN itself is SQL-only-bootstrapped, see
 *    docs/personal_trainer/03-backend-terv.md §RoleManagementService), so this
 *    test grants it via a direct DB write instead — the same kind of one-off
 *    a real deployment does by hand
 *  - the workout template assigned to the client is created through the real
 *    API using the trainer's own starter-catalog exercises (seeded on
 *    registration by StarterCatalogListener), not a pre-existing fixture
 *
 * Requires the real backend + Postgres running on localhost:8080/5432 (see
 * playwright.config.ts, which only auto-starts the Next.js dev server) — not
 * mocked, unlike the Vitest unit suite. The Postgres connection uses the same
 * default local dev credentials as docker-compose.yml/application.yml.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = {
  host: "localhost",
  port: 5432,
  database: "lifey",
  user: "lifey",
  password: "lifey",
};

/** Mirrors ClientAvatar.tsx's nameFor() — the client rows in the dashboard
 *  and assign drawer render this derived display name, not the raw email. */
function nameFor(email: string): string {
  const local = email.split("@")[0] ?? email;
  return local
    .split(/[._-]/)
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

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

/** Grants ROLE_TRAINER directly in Postgres — see the file-level doc comment
 *  for why this can't go through the HTTP API. */
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

test.describe("Personal trainer flow", () => {
  test("invite, API-simulated accept, assign, then visible in client detail", async ({ page, request }) => {
    const runId = Date.now();
    const trainerEmail = `e2e-trainer-${runId}@example.com`;
    const trainerPassword = "E2eTrainer123!";
    const clientEmail = `e2e-client-${runId}@example.com`;
    const clientPassword = "E2eClient123!";
    const clientDisplayName = nameFor(clientEmail);
    const templateName = `E2E Push Day ${runId}`;

    let trainerAccessToken = "";

    await test.step("register a fresh trainer and client, grant ROLE_TRAINER", async () => {
      const trainer = await registerAndLogin(request, trainerEmail, trainerPassword);
      await grantTrainerRole(trainer.userId);
      await registerAndLogin(request, clientEmail, clientPassword);

      // Re-login: the first trainer token was minted before the role grant,
      // so its `roles` claim is stale (JWTs aren't re-issued retroactively).
      const reLoginRes = await request.post(`${API_BASE}/auth/login`, {
        data: { email: trainerEmail, password: trainerPassword },
      });
      expect(reLoginRes.ok()).toBeTruthy();
      trainerAccessToken = (await reLoginRes.json()).accessToken;
    });

    await test.step("trainer creates their own workout template via the API", async () => {
      const exercisesRes = await request.get(`${API_BASE}/exercises`, {
        headers: { Authorization: `Bearer ${trainerAccessToken}` },
      });
      expect(exercisesRes.ok(), await exercisesRes.text()).toBeTruthy();
      const exercises: Array<{ id: number }> = await exercisesRes.json();
      expect(exercises.length, "expected the starter-catalog exercises to exist").toBeGreaterThan(0);

      const createRes = await request.post(`${API_BASE}/workout-templates`, {
        headers: { Authorization: `Bearer ${trainerAccessToken}` },
        data: { name: templateName, exercises: [{ exerciseId: exercises[0].id, targetSets: 3 }] },
      });
      expect(createRes.ok(), await createRes.text()).toBeTruthy();
    });

    await test.step("trainer logs in through the real UI", async () => {
      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(trainerEmail);
      await page.getByPlaceholder("••••••••").fill(trainerPassword);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL("**/dashboard");
    });

    await test.step("trainer invites the client by email", async () => {
      await page.goto("/admin/invites");
      await page.getByPlaceholder("client@example.com").fill(clientEmail);
      await page.getByRole("button", { name: "Invite" }).click();
      await expect(page.getByText(clientEmail)).toBeVisible();
    });

    await test.step("client accepts the invite (API-simulated)", async () => {
      const clientLoginRes = await request.post(`${API_BASE}/auth/login`, {
        data: { email: clientEmail, password: clientPassword },
      });
      expect(clientLoginRes.ok(), await clientLoginRes.text()).toBeTruthy();
      const { accessToken } = await clientLoginRes.json();

      const pendingRes = await request.get(`${API_BASE}/trainer-invites/pending`, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      expect(pendingRes.ok()).toBeTruthy();
      const pending: Array<{ id: number; trainerEmail: string }> = await pendingRes.json();
      const invite = pending.find((i) => i.trainerEmail === trainerEmail);
      expect(invite, "expected a pending invite from the trainer").toBeTruthy();

      const respondRes = await request.post(`${API_BASE}/trainer-invites/${invite!.id}/respond`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        data: { accept: true },
      });
      expect(respondRes.ok(), await respondRes.text()).toBeTruthy();
    });

    await test.step("client appears in the trainer's dashboard", async () => {
      await page.goto("/admin");
      // The "Your clients" modal (ClientListModal) also lists the client on
      // first load, so this name legitimately appears twice — assert presence.
      await expect(page.getByText(clientDisplayName).first()).toBeVisible();
      // Dismiss it so it doesn't intercept later clicks on this page.
      await page.getByRole("button", { name: "Close" }).click();
    });

    await test.step("trainer assigns their new template to the new client", async () => {
      await page.goto("/admin/workouts");
      const templateRow = page.getByTestId("template-row").filter({ hasText: templateName });
      await templateRow.getByTestId("assign-template").click();

      const drawer = page.getByTestId("assign-to-client-drawer");
      await drawer.getByPlaceholder("Search client…").fill(clientEmail);
      await drawer.getByTestId("assign-drawer-client-row").filter({ hasText: clientDisplayName }).click();
      await drawer.getByTestId("assign-drawer-submit").click();
      await expect(page.getByText(/Assigned/i)).toBeVisible();
    });

    await test.step("assigned plan is visible in the client's detail overview", async () => {
      await page.goto("/admin");
      const card = page.locator(`[data-testid="client-card"][data-client-email="${clientEmail}"]`);
      await card.getByLabel("Client options").click();
      await card.getByRole("link", { name: "Open" }).click();
      await expect(page.getByText(clientEmail)).toBeVisible(); // ClientDetailHeader shows the raw email
      await expect(page.getByText(templateName)).toBeVisible();
    });

    const mealFoodName = `E2E Oatmeal ${runId}`;

    await test.step("client logs a meal for yesterday via the API", async () => {
      const clientLoginRes = await request.post(`${API_BASE}/auth/login`, {
        data: { email: clientEmail, password: clientPassword },
      });
      expect(clientLoginRes.ok(), await clientLoginRes.text()).toBeTruthy();
      const { accessToken: clientAccessToken } = await clientLoginRes.json();

      const foodRes = await request.post(`${API_BASE}/foods`, {
        headers: { Authorization: `Bearer ${clientAccessToken}` },
        data: {
          name: mealFoodName,
          caloriesPer100g: 350,
          proteinPer100g: 12,
          carbsPer100g: 60,
          fatPer100g: 6,
          hidden: false,
        },
      });
      expect(foodRes.ok(), await foodRes.text()).toBeTruthy();
      const food: { id: number } = await foodRes.json();

      // Noon (not midnight) avoids day-boundary flakiness when the test runs
      // close to midnight in the server's local timezone.
      const yesterdayNoon = new Date();
      yesterdayNoon.setDate(yesterdayNoon.getDate() - 1);
      yesterdayNoon.setHours(12, 0, 0, 0);

      const mealRes = await request.post(`${API_BASE}/meals`, {
        headers: { Authorization: `Bearer ${clientAccessToken}` },
        data: {
          dateTime: yesterdayNoon.toISOString(),
          mealType: "LUNCH",
          entries: [{ foodId: food.id, quantityInGrams: 200 }],
        },
      });
      expect(mealRes.ok(), await mealRes.text()).toBeTruthy();
    });

    await test.step("trainer's Nutrition tab shows today empty and is read-only", async () => {
      await page.getByRole("button", { name: "Nutrition" }).click();
      await expect(page.getByText("Daily summary")).toBeVisible();
      await expect(page.getByText(mealFoodName)).not.toBeVisible();
      await expect(page.getByLabel("Edit meal")).toHaveCount(0);
      await expect(page.getByLabel("Remove meal")).toHaveCount(0);
      await expect(page.getByRole("button", { name: /Add to/ })).toHaveCount(0);
    });

    await test.step("day navigator reveals yesterday's logged meal", async () => {
      await page.getByLabel("Previous day").click();
      // The food name legitimately appears twice for a single-entry meal:
      // once as the card title, once as the ingredient row.
      await expect(page.getByText(mealFoodName).first()).toBeVisible();
      await expect(page.getByLabel("Edit meal")).toHaveCount(0);
      await expect(page.getByLabel("Remove meal")).toHaveCount(0);
    });
  });
});
