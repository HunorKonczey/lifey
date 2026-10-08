import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";
import { format, subDays } from "date-fns";

/**
 * What the trainer's client summary says about the client's goals and the week's plan (LIF-101, LIF-102): the step goal
 * the client set, the goal they stated in onboarding, and how many scheduled sessions fall in the last 7 days. On the
 * web the step goal is what gives the client's steps tab its goal line and its "Goal met" card, and the trainer can set
 * that goal from the same tab (LIF-105) — the client's own settings then carry it.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2eGoals123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Goals" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  return { userId: user.id, accessToken: (await loginRes.json()).accessToken as string };
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

async function connect(request: APIRequestContext, trainerToken: string, clientEmail: string) {
  const client = await registerAndLogin(request, clientEmail);
  const invite: { id: number } = await (await request.post(`${API_BASE}/trainer/invites`, { headers: { Authorization: `Bearer ${trainerToken}` }, data: { email: clientEmail } })).json();
  const respondRes = await request.post(`${API_BASE}/trainer-invites/${invite.id}/respond`, { headers: { Authorization: `Bearer ${client.accessToken}` }, data: { accept: true } });
  expect(respondRes.ok(), await respondRes.text()).toBeTruthy();
  return client;
}

test("the client summary carries the step goal, the stated goal and the week's plan — and the steps tab draws the goal", async ({ page, request }) => {
  const runId = Date.now();
  const trainerEmail = `e2e-goals-trainer-${runId}@example.com`;
  const withGoalsEmail = `e2e-goals-client-${runId}@example.com`;
  const bareEmail = `e2e-goals-bare-${runId}@example.com`;
  const today = new Date();
  const todayIso = format(today, "yyyy-MM-dd");

  let trainerAuth: Record<string, string> = {};
  let withGoalsId = 0;
  let bareId = 0;
  let bareToken = "";

  await test.step("a trainer with two clients: one who set goals and trained for it, one who set nothing", async () => {
    const trainer = await registerAndLogin(request, trainerEmail);
    await grantTrainerRole(trainer.userId);
    // The roles ride in the JWT, so the grant only shows in a token issued after it.
    const trainerToken: string = (await (await request.post(`${API_BASE}/auth/login`, { data: { email: trainerEmail, password: PASSWORD } })).json()).accessToken;
    trainerAuth = { Authorization: `Bearer ${trainerToken}` };

    const withGoals = await connect(request, trainerToken, withGoalsEmail);
    bareToken = (await connect(request, trainerToken, bareEmail)).accessToken;
    const auth = { Authorization: `Bearer ${withGoals.accessToken}` };

    const detailsRes = await request.put(`${API_BASE}/user-details`, {
      headers: auth,
      data: { gender: "FEMALE", birthDate: "1994-05-12", heightCm: 168, activityLevel: "MODERATE", primaryGoal: "GAIN_MUSCLE" },
    });
    expect(detailsRes.ok(), await detailsRes.text()).toBeTruthy();

    const settings = await (await request.get(`${API_BASE}/settings`, { headers: auth })).json();
    const settingsRes = await request.put(`${API_BASE}/settings`, { headers: auth, data: { ...settings, dailyStepGoal: 8000 } });
    expect(settingsRes.ok(), await settingsRes.text()).toBeTruthy();

    // Three finished days around the goal: two reach it, one does not.
    for (const [back, steps] of [[3, 9000], [2, 8500], [1, 6000]] as const) {
      const res = await request.post(`${API_BASE}/steps`, { headers: auth, data: { date: format(subDays(today, back), "yyyy-MM-dd"), steps } });
      expect(res.ok(), await res.text()).toBeTruthy();
    }

    const clients: Array<{ clientId: number; clientEmail: string }> = await (await request.get(`${API_BASE}/trainer/clients`, { headers: trainerAuth })).json();
    withGoalsId = clients.find((c) => c.clientEmail === withGoalsEmail)!.clientId;
    bareId = clients.find((c) => c.clientEmail === bareEmail)!.clientId;

    const exercises: Array<{ id: number }> = await (await request.get(`${API_BASE}/exercises`, { headers: trainerAuth })).json();
    const tplRes = await request.post(`${API_BASE}/workout-templates`, { headers: trainerAuth, data: { name: `Goals ${runId}`, exercises: [{ exerciseId: exercises[0].id, targetSets: 3 }] } });
    expect(tplRes.ok(), await tplRes.text()).toBeTruthy();
    const scheduleRes = await request.post(`${API_BASE}/trainer/schedules`, {
      headers: trainerAuth,
      data: { clientId: withGoalsId, templateId: (await tplRes.json()).id, recurrence: "ONCE", daysOfWeek: [], timeOfDay: null, startDate: todayIso, endDate: todayIso },
    });
    expect(scheduleRes.ok(), await scheduleRes.text()).toBeTruthy();
  });

  await test.step("GET /trainer/clients reports them, and leaves them out for the client who set nothing", async () => {
    const clients: Array<Record<string, unknown>> = await (await request.get(`${API_BASE}/trainer/clients`, { headers: trainerAuth })).json();
    const withGoals = clients.find((c) => c.clientId === withGoalsId)!;
    const bare = clients.find((c) => c.clientId === bareId)!;

    expect(withGoals).toMatchObject({ dailyStepGoal: 8000, primaryGoal: "GAIN_MUSCLE", plannedSessions7d: 1, completedSessions7d: 0 });
    expect(bare.dailyStepGoal ?? null).toBeNull();
    expect(bare.primaryGoal ?? null).toBeNull();
    // Nothing scheduled is a real zero, not a missing figure.
    expect(bare).toMatchObject({ plannedSessions7d: 0, completedSessions7d: 0 });
  });

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(trainerEmail);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|admin/);

  await test.step("the client's steps tab draws the goal line and counts the days that met it", async () => {
    await page.goto(`/admin/clients/${withGoalsId}`);
    await page.getByRole("tab", { name: "Steps" }).click();
    await expect(page.getByText("Goal met")).toBeVisible();
    await expect(page.getByText("✓ goal reached · 8,000")).toBeVisible();
  });

  await test.step("a client who set no goal gets no goal card and no made-up line", async () => {
    await page.goto(`/admin/clients/${bareId}`);
    // No steps logged: the tab's own empty state, which has nothing to draw a goal on either.
    await page.getByRole("tab", { name: "Steps" }).click();
    await expect(page.getByText("Goal met")).toHaveCount(0);
    await expect(page.getByText(/goal reached/)).toHaveCount(0);
  });

  await test.step("the trainer sets the goal from the steps tab: zero is refused, a number is saved and reaches the client", async () => {
    await page.goto(`/admin/clients/${bareId}`);
    await page.getByRole("tab", { name: "Steps" }).click();
    await expect(page.getByTestId("step-goal-value")).toHaveText("No step goal set");

    await page.getByTestId("step-goal-edit").click();
    const drawer = page.getByRole("dialog", { name: "Daily step goal" });
    await drawer.getByLabel("Steps a day").fill("0");
    await expect(drawer.getByText("Enter a whole number above zero, or leave it empty")).toBeVisible();
    await expect(drawer.getByRole("button", { name: "Save" })).toBeDisabled();

    await drawer.getByLabel("Steps a day").fill("6500");
    await drawer.getByRole("button", { name: "Save" }).click();
    await expect(page.getByText("Step goal updated")).toBeVisible();
    await expect(page.getByTestId("step-goal-value")).toHaveText("6,500 steps a day");

    // What the client's own app reads on its next sync.
    const settings = await (await request.get(`${API_BASE}/settings`, { headers: { Authorization: `Bearer ${bareToken}` } })).json();
    expect(settings.dailyStepGoal).toBe(6500);
  });

  await test.step("an empty field clears it again", async () => {
    await page.getByTestId("step-goal-edit").click();
    const drawer = page.getByRole("dialog", { name: "Daily step goal" });
    await drawer.getByLabel("Steps a day").fill("");
    await drawer.getByRole("button", { name: "Save" }).click();
    await expect(page.getByTestId("step-goal-value")).toHaveText("No step goal set");
    const settings = await (await request.get(`${API_BASE}/settings`, { headers: { Authorization: `Bearer ${bareToken}` } })).json();
    expect(settings.dailyStepGoal ?? null).toBeNull();
  });
});
