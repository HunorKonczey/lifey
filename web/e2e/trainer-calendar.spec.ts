import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";
import { addDays, addWeeks, format, startOfWeek } from "date-fns";
import { enUS } from "date-fns/locale";

/**
 * End-to-end trainer calendar flow (docs/personal_trainer/12-edzo-naptar-terv.md) —
 * the aggregated `/admin/calendar` view: week/month toggle, client filter,
 * session-peek cancellation (and that it's reflected on the client's own
 * Ütemterv tab), and scheduling a workout from a day column's "+".
 *
 * Self-contained like trainer-flow.spec.ts: fresh trainer + two fresh clients
 * per run, ROLE_TRAINER granted via a direct DB write (no grant API by design).
 * Requires the real backend + Postgres on localhost:8080/5432.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = {
  host: "localhost",
  port: 5432,
  database: "lifey",
  user: "lifey",
  password: "lifey",
};

/** Mirrors ClientAvatar.tsx's nameFor(). */
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

async function inviteAndAccept(request: APIRequestContext, trainerAccessToken: string, trainerEmail: string, clientEmail: string, clientPassword: string) {
  const inviteRes = await request.post(`${API_BASE}/trainer/invites`, {
    headers: { Authorization: `Bearer ${trainerAccessToken}` },
    data: { email: clientEmail },
  });
  expect(inviteRes.ok(), await inviteRes.text()).toBeTruthy();

  const clientLoginRes = await request.post(`${API_BASE}/auth/login`, {
    data: { email: clientEmail, password: clientPassword },
  });
  expect(clientLoginRes.ok(), await clientLoginRes.text()).toBeTruthy();
  const { accessToken: clientAccessToken } = await clientLoginRes.json();

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

async function scheduleOnce(request: APIRequestContext, trainerAccessToken: string, clientId: number, templateId: number, dateIso: string) {
  const res = await request.post(`${API_BASE}/trainer/schedules`, {
    headers: { Authorization: `Bearer ${trainerAccessToken}` },
    data: {
      clientId,
      templateId,
      recurrence: "ONCE",
      daysOfWeek: [],
      timeOfDay: null,
      startDate: dateIso,
      endDate: dateIso,
    },
  });
  expect(res.ok(), await res.text()).toBeTruthy();
}

test.describe("Trainer calendar", () => {
  test("week/month toggle, client filter, session-peek cancel, and schedule-from-day", async ({ page, request }) => {
    const runId = Date.now();
    const trainerEmail = `e2e-trainer-cal-${runId}@example.com`;
    const trainerPassword = "E2eTrainer123!";
    const clientAEmail = `e2e-clienta-${runId}@example.com`;
    const clientBEmail = `e2e-clientb-${runId}@example.com`;
    const clientPassword = "E2eClient123!";
    const clientAName = nameFor(clientAEmail);
    const clientBName = nameFor(clientBEmail);
    const templateName = `E2E Calendar Push Day ${runId}`;
    const today = format(new Date(), "yyyy-MM-dd");
    const nextMonday = startOfWeek(addWeeks(new Date(), 1), { weekStartsOn: 1 });
    // Seeds next week with one occurrence (on a *different* day than the one
    // we click "+" on) so the grid renders instead of the empty-period state.
    const nextWednesday = format(addDays(nextMonday, 2), "yyyy-MM-dd");

    let trainerAccessToken = "";
    let clientAId = 0;
    let clientBId = 0;
    let templateId = 0;

    await test.step("register trainer + two clients, grant ROLE_TRAINER, both accept invites", async () => {
      const trainer = await registerAndLogin(request, trainerEmail, trainerPassword);
      await grantTrainerRole(trainer.userId);
      await registerAndLogin(request, clientAEmail, clientPassword);
      await registerAndLogin(request, clientBEmail, clientPassword);

      const reLoginRes = await request.post(`${API_BASE}/auth/login`, {
        data: { email: trainerEmail, password: trainerPassword },
      });
      expect(reLoginRes.ok()).toBeTruthy();
      trainerAccessToken = (await reLoginRes.json()).accessToken;

      await inviteAndAccept(request, trainerAccessToken, trainerEmail, clientAEmail, clientPassword);
      await inviteAndAccept(request, trainerAccessToken, trainerEmail, clientBEmail, clientPassword);

      const clientsRes = await request.get(`${API_BASE}/trainer/clients`, {
        headers: { Authorization: `Bearer ${trainerAccessToken}` },
      });
      expect(clientsRes.ok(), await clientsRes.text()).toBeTruthy();
      const clients: Array<{ clientId: number; clientEmail: string }> = await clientsRes.json();
      clientAId = clients.find((c) => c.clientEmail === clientAEmail)!.clientId;
      clientBId = clients.find((c) => c.clientEmail === clientBEmail)!.clientId;
      expect(clientAId, "clientA should be in the trainer's roster").toBeTruthy();
      expect(clientBId, "clientB should be in the trainer's roster").toBeTruthy();
    });

    await test.step("trainer creates a workout template and schedules today's workout for both clients", async () => {
      const exercisesRes = await request.get(`${API_BASE}/exercises`, {
        headers: { Authorization: `Bearer ${trainerAccessToken}` },
      });
      expect(exercisesRes.ok(), await exercisesRes.text()).toBeTruthy();
      const exercises: Array<{ id: number }> = await exercisesRes.json();
      expect(exercises.length).toBeGreaterThan(0);

      const createRes = await request.post(`${API_BASE}/workout-templates`, {
        headers: { Authorization: `Bearer ${trainerAccessToken}` },
        data: { name: templateName, exercises: [{ exerciseId: exercises[0].id, targetSets: 3 }] },
      });
      expect(createRes.ok(), await createRes.text()).toBeTruthy();
      templateId = (await createRes.json()).id;

      await scheduleOnce(request, trainerAccessToken, clientAId, templateId, today);
      await scheduleOnce(request, trainerAccessToken, clientBId, templateId, today);
      await scheduleOnce(request, trainerAccessToken, clientAId, templateId, nextWednesday);
    });

    await test.step("trainer logs in and opens the calendar from the admin sidebar", async () => {
      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(trainerEmail);
      await page.getByPlaceholder("••••••••").fill(trainerPassword);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL("**/dashboard");

      await page.getByRole("link", { name: "Trainer view" }).click();
      await page.waitForURL("**/admin");
      // First visit shows the "Your clients" modal (ClientListModal) — dismiss
      // it so it doesn't intercept the sidebar click.
      await page.getByRole("button", { name: "Close" }).click();

      await page.getByRole("link", { name: "Calendar" }).click();
      await page.waitForURL("**/admin/calendar");
    });

    await test.step("both clients' today workouts are visible in the week view", async () => {
      await expect(page.getByTestId("calendar-session-card").filter({ hasText: clientAName })).toBeVisible();
      await expect(page.getByTestId("calendar-session-card").filter({ hasText: clientBName })).toBeVisible();
    });

    await test.step("toggling to Month view and back doesn't lose the data", async () => {
      await page.getByRole("tab", { name: "Month" }).click();
      await expect(page.getByRole("tab", { name: "Month", selected: true })).toBeVisible();
      await page.getByRole("tab", { name: "Week" }).click();
      await expect(page.getByRole("tab", { name: "Week", selected: true })).toBeVisible();
      await expect(page.getByTestId("calendar-session-card").filter({ hasText: clientAName })).toBeVisible();
    });

    await test.step("client filter narrows the view to a single client", async () => {
      const filter = page.getByTestId("calendar-client-filter");
      await filter.getByTestId("calendar-client-filter-trigger").click();
      await filter.getByTestId("calendar-client-filter-row").filter({ hasText: clientBName }).click();
      await page.keyboard.press("Escape");

      await expect(page.getByTestId("calendar-session-card").filter({ hasText: clientAName })).toBeVisible();
      await expect(page.getByTestId("calendar-session-card").filter({ hasText: clientBName })).not.toBeVisible();

      await filter.getByTestId("calendar-client-filter-trigger").click();
      await filter.getByTestId("calendar-client-filter-all").click();
      await page.keyboard.press("Escape");
      await expect(page.getByTestId("calendar-session-card").filter({ hasText: clientBName })).toBeVisible();
    });

    await test.step("cancelling client A's occurrence from the session-peek", async () => {
      await page.getByTestId("calendar-session-card").filter({ hasText: clientAName }).click();
      const peek = page.getByRole("dialog", { name: "Workout details" });
      await expect(peek.getByText(clientAName)).toBeVisible();

      await peek.getByRole("button", { name: "Cancel this workout" }).click();
      await peek.getByRole("button", { name: "Cancel workout" }).click();
      await expect(page.getByText("Workout cancelled")).toBeVisible();

      // Hidden by default once cancelled (the "Cancelled" toggle defaults off).
      await expect(page.getByTestId("calendar-session-card").filter({ hasText: clientAName })).not.toBeVisible();
    });

    await test.step("the cancellation is reflected on client A's own schedule tab", async () => {
      await page.goto(`/admin/clients/${clientAId}?tab=schedule`);
      await expect(page.getByText("cancelled")).toBeVisible();
    });

    await test.step("scheduling a new workout for client B from next week's day-column \"+\"", async () => {
      await page.goto("/admin/calendar");
      await page.getByRole("button", { name: "Next week" }).click();

      const dayLabel = format(nextMonday, "MMM d.", { locale: enUS });
      await page.getByLabel(`Schedule a workout for ${dayLabel}`).click();

      const drawer = page.getByTestId("schedule-workout-drawer");
      await expect(drawer.getByText(format(nextMonday, "PP", { locale: enUS }))).toBeVisible();

      await drawer.getByPlaceholder("Search client…").fill(clientBEmail);
      await drawer.getByTestId("schedule-drawer-client-row").filter({ hasText: clientBName }).click();
      await drawer.getByPlaceholder("Search your templates…").fill(templateName);
      await drawer.getByTestId("schedule-drawer-template-row").filter({ hasText: templateName }).click();
      await drawer.getByTestId("schedule-drawer-submit").click();

      await expect(page.getByText(`1 workout scheduled for ${clientBName}`)).toBeVisible();
      await expect(page.getByTestId("calendar-session-card").filter({ hasText: clientBName })).toBeVisible();
    });
  });
});
