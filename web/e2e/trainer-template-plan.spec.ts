import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";
import { format } from "date-fns";

/**
 * What a trainer says about a workout template - how long it takes and how many repetitions each exercise asks for - and
 * who uses it (LIF-106): the editor stores both, a save from the phone (which knows neither) leaves them alone, an emptied
 * field clears them, and "Used by" counts a client who only has the template in a running schedule.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2eTemplatePlan123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Plan" } });
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

test("a trainer states a template's duration and repetitions, the phone cannot erase them, and a scheduled client counts as a user", async ({ page, request }) => {
  const runId = Date.now();
  const trainerEmail = `e2e-plan-trainer-${runId}@example.com`;
  const clientEmail = `e2e-plan-client-${runId}@example.com`;
  const templateName = `Plan ${runId}`;
  const today = format(new Date(), "yyyy-MM-dd");

  let auth: Record<string, string> = {};
  let templateId = 0;
  let exerciseId = 0;
  let clientId = 0;

  await test.step("a trainer with a connected client and one template of one exercise", async () => {
    const trainer = await registerAndLogin(request, trainerEmail);
    await grantTrainerRole(trainer.userId);
    // The roles ride in the JWT, so the grant only shows in a token issued after it.
    const token: string = (await (await request.post(`${API_BASE}/auth/login`, { data: { email: trainerEmail, password: PASSWORD } })).json()).accessToken;
    auth = { Authorization: `Bearer ${token}` };

    const client = await registerAndLogin(request, clientEmail);
    clientId = client.userId;
    const invite: { id: number } = await (await request.post(`${API_BASE}/trainer/invites`, { headers: auth, data: { email: clientEmail } })).json();
    const respondRes = await request.post(`${API_BASE}/trainer-invites/${invite.id}/respond`, { headers: { Authorization: `Bearer ${client.accessToken}` }, data: { accept: true } });
    expect(respondRes.ok(), await respondRes.text()).toBeTruthy();

    const exercises: Array<{ id: number }> = await (await request.get(`${API_BASE}/exercises`, { headers: auth })).json();
    exerciseId = exercises[0].id;
    const created = await request.post(`${API_BASE}/workout-templates`, { headers: auth, data: { name: templateName, exercises: [{ exerciseId, targetSets: 3 }] } });
    expect(created.ok(), await created.text()).toBeTruthy();
    templateId = (await created.json()).id;
  });

  const stored = async () => {
    const list: Array<{ id: number; durationMinutes?: number | null; exercises: Array<{ targetSets: number; targetReps?: number | null }> }> = await (
      await request.get(`${API_BASE}/workout-templates`, { headers: auth })
    ).json();
    return list.find((t) => t.id === templateId)!;
  };

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(trainerEmail);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|admin/);
  await page.goto("/admin/workouts");

  const row = page.getByRole("row").filter({ hasText: templateName });
  const editor = page.getByTestId("template-editor");

  await test.step("the editor takes a duration and a repetition count, and the table shows the stated time", async () => {
    await row.getByText(templateName).click();
    await expect(editor).toBeVisible();
    await editor.getByTestId("template-duration").fill("45");
    await editor.getByTestId("template-reps").fill("10");
    await expect(editor.getByTestId("template-totals")).toContainText("45 min");
    await editor.getByRole("button", { name: "Save template" }).click();
    await expect(page.getByText("Template updated")).toBeVisible();

    const t = await stored();
    expect(t.durationMinutes).toBe(45);
    expect(t.exercises[0].targetReps).toBe(10);
    await expect(row).toContainText("45 min");
  });

  await test.step("a save from the phone, which sends neither, leaves them alone", async () => {
    const phone = await request.put(`${API_BASE}/workout-templates/${templateId}`, {
      headers: auth,
      data: { name: templateName, exercises: [{ exerciseId, targetSets: 4 }] },
    });
    expect(phone.ok(), await phone.text()).toBeTruthy();

    const t = await stored();
    expect(t.exercises[0].targetSets).toBe(4);
    expect(t.durationMinutes).toBe(45);
    expect(t.exercises[0].targetReps).toBe(10);
  });

  await test.step("emptying the fields clears them", async () => {
    await page.reload();
    await row.getByText(templateName).click();
    await editor.getByTestId("template-duration").fill("");
    await editor.getByTestId("template-reps").fill("");
    await editor.getByRole("button", { name: "Save template" }).click();
    await expect(page.getByText("Template updated")).toBeVisible();

    const t = await stored();
    expect(t.durationMinutes ?? null).toBeNull();
    expect(t.exercises[0].targetReps ?? null).toBeNull();
  });

  await test.step("nobody uses it yet; a client who only has it in a running schedule counts", async () => {
    await page.reload();
    await expect(row).toContainText("nobody");

    const schedule = await request.post(`${API_BASE}/trainer/schedules`, {
      headers: auth,
      data: { clientId, templateId, recurrence: "ONCE", daysOfWeek: [], timeOfDay: null, startDate: today, endDate: today },
    });
    expect(schedule.ok(), await schedule.text()).toBeTruthy();

    const usage: Array<{ templateId: number; assignedClientIds: number[]; scheduledClientIds: number[] }> = await (await request.get(`${API_BASE}/trainer/templates/usage`, { headers: auth })).json();
    expect(usage.find((u) => u.templateId === templateId)?.scheduledClientIds).toEqual([clientId]);

    await page.reload();
    await expect(row).toContainText("1 client");
    await row.getByText(templateName).click();
    await expect(editor.getByTestId("template-impact")).toContainText("running schedule or program");
  });
});
