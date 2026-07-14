import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";

/**
 * End-to-end coverage for the trainer compliance overview (docs/29-compliance-overview-plan.md,
 * roadmap #12): a flagged client shows warning badges on their card and shows
 * up in the dashboard's "Needs attention" section, while an untouched
 * brand-new client shows neither.
 *
 * Some facts the plan requires (a missed occurrence, a stale weight log)
 * can't be produced through the API alone — `WorkoutScheduleServiceImpl`
 * refuses past `startDate`s, and `WeightEntry.recordedAt` is always stamped
 * "now" on insert — so this test backdates them directly in Postgres after
 * creating them through the real API, the same approach trainer-flow.spec.ts
 * uses for granting ROLE_TRAINER.
 *
 * Requires the real backend + Postgres running on localhost:8080/5432 (see
 * playwright.config.ts).
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = {
  host: "localhost",
  port: 5432,
  database: "lifey",
  user: "lifey",
  password: "lifey",
};

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

async function withDb<T>(fn: (db: Client) => Promise<T>): Promise<T> {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

async function grantTrainerRole(userId: number) {
  await withDb((db) =>
    db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [userId]),
  );
}

async function acceptInvite(request: APIRequestContext, clientAccessToken: string, trainerEmail: string) {
  const pendingRes = await request.get(`${API_BASE}/trainer-invites/pending`, {
    headers: { Authorization: `Bearer ${clientAccessToken}` },
  });
  expect(pendingRes.ok()).toBeTruthy();
  const pending: Array<{ id: number; trainerEmail: string }> = await pendingRes.json();
  const invite = pending.find((i) => i.trainerEmail === trainerEmail);
  expect(invite, "expected a pending invite from the trainer").toBeTruthy();

  const respondRes = await request.post(`${API_BASE}/trainer-invites/${invite!.id}/respond`, {
    headers: { Authorization: `Bearer ${clientAccessToken}` },
    data: { accept: true },
  });
  expect(respondRes.ok(), await respondRes.text()).toBeTruthy();
}

test.describe("Trainer compliance overview", () => {
  test("flagged client shows badges and appears in Needs attention; untouched client shows neither", async ({
    page,
    request,
  }) => {
    const runId = Date.now();
    const trainerEmail = `e2e-compliance-trainer-${runId}@example.com`;
    const trainerPassword = "E2eTrainer123!";
    const flaggedEmail = `e2e-compliance-flagged-${runId}@example.com`;
    const freshEmail = `e2e-compliance-fresh-${runId}@example.com`;
    const clientPassword = "E2eClient123!";
    const flaggedName = nameFor(flaggedEmail);
    const freshName = nameFor(freshEmail);

    let trainerToken = "";

    await test.step("register trainer + two clients, grant ROLE_TRAINER, accept both invites", async () => {
      const trainer = await registerAndLogin(request, trainerEmail, trainerPassword);
      await grantTrainerRole(trainer.userId);
      await registerAndLogin(request, flaggedEmail, clientPassword);
      await registerAndLogin(request, freshEmail, clientPassword);

      const reLogin = await request.post(`${API_BASE}/auth/login`, {
        data: { email: trainerEmail, password: trainerPassword },
      });
      trainerToken = (await reLogin.json()).accessToken;

      for (const clientEmail of [flaggedEmail, freshEmail]) {
        await request.post(`${API_BASE}/trainer/invites`, {
          headers: { Authorization: `Bearer ${trainerToken}` },
          data: { email: clientEmail },
        });
        const clientLogin = await request.post(`${API_BASE}/auth/login`, {
          data: { email: clientEmail, password: clientPassword },
        });
        const { accessToken: clientToken } = await clientLogin.json();
        await acceptInvite(request, clientToken, trainerEmail);
      }
    });

    await test.step("give the flagged client a missed workout, an old meal, and a stale weight log", async () => {
      const clientLogin = await request.post(`${API_BASE}/auth/login`, {
        data: { email: flaggedEmail, password: clientPassword },
      });
      const { accessToken: clientToken } = await clientLogin.json();

      // Missed workout: create today's one-off schedule via the real API (the
      // service rejects a past startDate), then backdate the occurrence.
      const exercisesRes = await request.get(`${API_BASE}/exercises`, {
        headers: { Authorization: `Bearer ${trainerToken}` },
      });
      const exercises: Array<{ id: number }> = await exercisesRes.json();
      const templateRes = await request.post(`${API_BASE}/workout-templates`, {
        headers: { Authorization: `Bearer ${trainerToken}` },
        data: { name: `E2E Compliance Template ${runId}`, exercises: [{ exerciseId: exercises[0].id, targetSets: 3 }] },
      });
      const template: { id: number } = await templateRes.json();

      const clientsRes = await request.get(`${API_BASE}/trainer/clients`, {
        headers: { Authorization: `Bearer ${trainerToken}` },
      });
      const clients: Array<{ clientId: number; clientEmail: string }> = await clientsRes.json();
      const flaggedClientId = clients.find((c) => c.clientEmail === flaggedEmail)!.clientId;

      const today = new Date().toISOString().slice(0, 10);
      const scheduleRes = await request.post(`${API_BASE}/trainer/schedules`, {
        headers: { Authorization: `Bearer ${trainerToken}` },
        data: {
          clientId: flaggedClientId,
          templateId: template.id,
          recurrence: "ONCE",
          daysOfWeek: [],
          startDate: today,
          endDate: today,
        },
      });
      const schedule: { id: number } = await scheduleRes.json();

      // Old meal (5 days ago) — the client's only activity, so it becomes lastActivityAt.
      const foodRes = await request.post(`${API_BASE}/foods`, {
        headers: { Authorization: `Bearer ${clientToken}` },
        data: {
          name: `E2E Compliance Food ${runId}`,
          caloriesPer100g: 350,
          proteinPer100g: 12,
          carbsPer100g: 60,
          fatPer100g: 6,
          hidden: false,
        },
      });
      const food: { id: number } = await foodRes.json();
      const fiveDaysAgoNoon = new Date();
      fiveDaysAgoNoon.setDate(fiveDaysAgoNoon.getDate() - 5);
      fiveDaysAgoNoon.setHours(12, 0, 0, 0);
      await request.post(`${API_BASE}/meals`, {
        headers: { Authorization: `Bearer ${clientToken}` },
        data: {
          dateTime: fiveDaysAgoNoon.toISOString(),
          mealType: "LUNCH",
          entries: [{ foodId: food.id, quantityInGrams: 200 }],
        },
      });

      // Weight entry — recordedAt gets backdated below so it reads as stale.
      const tenDaysAgo = new Date();
      tenDaysAgo.setDate(tenDaysAgo.getDate() - 10);
      const weightRes = await request.post(`${API_BASE}/weights`, {
        headers: { Authorization: `Bearer ${clientToken}` },
        data: { date: tenDaysAgo.toISOString().slice(0, 10), weight: 80.5 },
      });
      const weight: { id: number } = await weightRes.json();

      await withDb(async (db) => {
        await db.query("update workout_sessions set scheduled_for = current_date - interval '3 days' where schedule_id = $1", [
          schedule.id,
        ]);
        await db.query("update weight_entries set recorded_at = current_timestamp - interval '10 days' where id = $1", [
          weight.id,
        ]);
      });
    });

    await test.step("trainer logs in and sees the flagged client's badges and Needs attention entry", async () => {
      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(trainerEmail);
      await page.getByPlaceholder("••••••••").fill(trainerPassword);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL("**/dashboard");

      await page.goto("/admin");
      await page.getByRole("button", { name: "Close" }).click();

      const needsAttention = page.getByText(/Needs attention/);
      await expect(needsAttention).toBeVisible();
      await expect(page.getByText("1 missed workout").first()).toBeVisible();
      await expect(page.getByText(/days inactive/).first()).toBeVisible();
      await expect(page.getByText(/no weight for \d+ days/).first()).toBeVisible();

      const flaggedCard = page.locator(`[data-testid="client-card"][data-client-email="${flaggedEmail}"]`);
      await expect(flaggedCard.getByText("1 missed workout")).toBeVisible();

      const freshCard = page.locator(`[data-testid="client-card"][data-client-email="${freshEmail}"]`);
      await expect(freshCard.getByText(/missed workout|inactive|no weight/)).toHaveCount(0);
    });

    await test.step("sorting by Least active first moves the flagged client to the top", async () => {
      await page.getByLabel("Sort clients").selectOption("leastActive");
      const cards = page.getByTestId("client-card");
      await expect(cards.first()).toHaveAttribute("data-client-email", flaggedEmail);
    });
  });
});
