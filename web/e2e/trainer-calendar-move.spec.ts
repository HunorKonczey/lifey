import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";
import { addDays, format } from "date-fns";

/**
 * Moving a scheduled workout without dragging (LIF-140): the session peek's "Move…" opens a dialog with a day and a time,
 * reachable and operable from the keyboard. The drag onto another cell stays as the pointer shortcut.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };

async function registerAndLogin(request: APIRequestContext, email: string, password: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password, firstName: "E2E", lastName: "Move" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password } });
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

test("Move… in the session peek moves a workout to another day and time, from the keyboard", async ({ page, request }) => {
  const runId = Date.now();
  const trainerEmail = `e2e-move-trainer-${runId}@example.com`;
  const clientEmail = `e2e-move-client-${runId}@example.com`;
  const password = "E2eMove123!";
  const today = new Date();
  const target = addDays(today, 2);
  const targetIso = format(target, "yyyy-MM-dd");

  let trainerToken = "";
  let sessionId = 0;

  await test.step("a trainer, a connected client and one workout scheduled today", async () => {
    const trainer = await registerAndLogin(request, trainerEmail, password);
    await grantTrainerRole(trainer.userId);
    const client = await registerAndLogin(request, clientEmail, password);
    trainerToken = (await (await request.post(`${API_BASE}/auth/login`, { data: { email: trainerEmail, password } })).json()).accessToken;
    const auth = { Authorization: `Bearer ${trainerToken}` };

    const inviteRes = await request.post(`${API_BASE}/trainer/invites`, { headers: auth, data: { email: clientEmail } });
    expect(inviteRes.ok(), await inviteRes.text()).toBeTruthy();
    const invite: { id: number } = await inviteRes.json();
    const respondRes = await request.post(`${API_BASE}/trainer-invites/${invite.id}/respond`, { headers: { Authorization: `Bearer ${client.accessToken}` }, data: { accept: true } });
    expect(respondRes.ok(), await respondRes.text()).toBeTruthy();

    const exercises: Array<{ id: number }> = await (await request.get(`${API_BASE}/exercises`, { headers: auth })).json();
    const tplRes = await request.post(`${API_BASE}/workout-templates`, { headers: auth, data: { name: `Move ${runId}`, exercises: [{ exerciseId: exercises[0].id, targetSets: 3 }] } });
    expect(tplRes.ok(), await tplRes.text()).toBeTruthy();
    const templateId = (await tplRes.json()).id;
    const clients: Array<{ clientId: number; clientEmail: string }> = await (await request.get(`${API_BASE}/trainer/clients`, { headers: auth })).json();
    const clientId = clients.find((c) => c.clientEmail === clientEmail)!.clientId;
    const todayIso = format(today, "yyyy-MM-dd");
    const scheduleRes = await request.post(`${API_BASE}/trainer/schedules`, {
      headers: auth,
      data: { clientId, templateId, recurrence: "ONCE", daysOfWeek: [], timeOfDay: null, startDate: todayIso, endDate: todayIso },
    });
    expect(scheduleRes.ok(), await scheduleRes.text()).toBeTruthy();
    const sessions: Array<{ sessionId: number; scheduledFor: string }> = await (await request.get(`${API_BASE}/trainer/scheduled-sessions?from=${todayIso}&to=${targetIso}`, { headers: auth })).json();
    sessionId = sessions.find((s) => s.scheduledFor === todayIso)!.sessionId;
  });

  await test.step("open the calendar and the workout's peek with the keyboard", async () => {
    await page.goto("/login");
    await page.getByPlaceholder("you@example.com").fill(trainerEmail);
    await page.getByPlaceholder("••••••••").fill(password);
    await page.getByRole("button", { name: "Sign in" }).click();
    await page.waitForURL(/dashboard|admin/);
    await page.goto("/admin/calendar");
    const card = page.getByTestId("calendar-session-card");
    await expect(card).toBeVisible();
    await card.focus();
    await page.keyboard.press("Enter");
    await expect(page.getByTestId("calendar-peek-move")).toBeVisible();
  });

  await test.step("Move… opens a dialog; today and the original time are the starting point and cannot be submitted", async () => {
    await page.getByTestId("calendar-peek-move").focus();
    await page.keyboard.press("Enter");
    const dialog = page.getByRole("dialog", { name: "Move workout" });
    await expect(dialog).toBeVisible();
    await expect(dialog.getByTestId("calendar-move-apply")).toBeDisabled();

    await test.step("a day in the past is refused", async () => {
      await dialog.getByLabel("Date – day").fill(String(Math.max(1, today.getDate() - 1)).padStart(2, "0"));
      if (today.getDate() > 1) await expect(dialog.getByText("Pick today or a later day")).toBeVisible();
      await expect(dialog.getByTestId("calendar-move-apply")).toBeDisabled();
    });

    await test.step("two days ahead at 18:00 can be applied", async () => {
      await dialog.getByLabel("Date – month").fill(format(target, "MM"));
      await dialog.getByLabel("Date – day").fill(format(target, "dd"));
      await dialog.getByLabel("Date – year").fill(format(target, "yyyy"));
      // The quick-time chip is labelled in the UI locale: "6:00 PM" in English.
      await dialog.getByRole("button", { name: /^6:00\sPM$/ }).click();
      await expect(dialog.getByTestId("calendar-move-apply")).toBeEnabled();
      await dialog.getByTestId("calendar-move-apply").focus();
      await page.keyboard.press("Enter");
    });
  });

  await test.step("the workout really moved (toast, and the API says so)", async () => {
    await expect(page.getByText("Workout moved")).toBeVisible();
    await expect(page.getByRole("dialog", { name: "Move workout" })).toHaveCount(0);
    const sessions: Array<{ sessionId: number; scheduledFor: string; scheduledTime: string | null }> = await (
      await request.get(`${API_BASE}/trainer/scheduled-sessions?from=${format(today, "yyyy-MM-dd")}&to=${targetIso}`, { headers: { Authorization: `Bearer ${trainerToken}` } })
    ).json();
    const moved = sessions.find((s) => s.sessionId === sessionId)!;
    expect(moved.scheduledFor).toBe(targetIso);
    expect(moved.scheduledTime?.slice(0, 5)).toBe("18:00");
  });
});
