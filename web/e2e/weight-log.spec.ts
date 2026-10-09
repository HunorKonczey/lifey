import { test, expect, type APIRequestContext } from "@playwright/test";
import { format } from "date-fns";

/**
 * A weigh-in's time and note (LIF-115): the drawer takes a note, the log shows it and the time of day the weigh-in was
 * taken, an edit keeps that time, and a back-dated entry shows no time (it was not taken on the day it is for).
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const PASSWORD = "E2eWeightLog123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Weigh" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  return (await loginRes.json()).accessToken as string;
}

test("a weigh-in keeps its note and the time it was taken; an edit keeps the time; a back-dated entry has none", async ({ page, request }) => {
  const email = `e2e-weight-log-${Date.now()}@example.com`;
  const token = await registerAndLogin(request, email);
  const auth = { Authorization: `Bearer ${token}` };
  const today = format(new Date(), "yyyy-MM-dd");
  const threeDaysAgo = format(new Date(Date.now() - 3 * 86_400_000), "yyyy-MM-dd");

  const stored = async () => {
    const list: Array<{ id: number; date: string; weight: number; recordedAt: string | null; note: string | null }> = await (await request.get(`${API_BASE}/weights`, { headers: auth })).json();
    return list;
  };

  await test.step("the API stores the client's own time and the trimmed note, and clamps a time in the future", async () => {
    const taken = new Date(Date.now() - 2 * 3600_000).toISOString();
    const created = await request.post(`${API_BASE}/weights`, { headers: auth, data: { date: today, weight: 80.4, recordedAt: taken, note: "  fasted, after a run  " } });
    expect(created.ok(), await created.text()).toBeTruthy();
    const body = await created.json();
    expect(body.note).toBe("fasted, after a run");
    expect(new Date(body.recordedAt).getTime()).toBe(new Date(taken).getTime());

    const future = await request.post(`${API_BASE}/weights`, { headers: auth, data: { date: today, weight: 80.2, recordedAt: new Date(Date.now() + 86_400_000).toISOString() } });
    expect(new Date((await future.json()).recordedAt).getTime()).toBeLessThanOrEqual(Date.now() + 1000);

    // Back to a single entry for the table assertions below; a back-dated one is added through the API too.
    for (const e of await stored()) if (e.weight === 80.2) await request.delete(`${API_BASE}/weights/${e.id}`, { headers: auth });
    const back = await request.post(`${API_BASE}/weights`, { headers: auth, data: { date: threeDaysAgo, weight: 81.0 } });
    expect(back.ok(), await back.text()).toBeTruthy();
  });

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|onboarding/);
  await page.goto("/weight");

  const log = page.getByTestId("weight-log");
  const todayRow = log.getByRole("row").filter({ hasText: "80.4" });
  const backRow = log.getByRole("row").filter({ hasText: "81" });

  await test.step("the log shows the note and the time for today's entry, and no time for the back-dated one", async () => {
    await expect(todayRow).toBeVisible();
    await expect(todayRow.getByTestId("weight-note-cell")).toHaveText("fasted, after a run");
    await expect(todayRow.getByTestId("weight-time")).toBeVisible();
    await expect(backRow).toBeVisible();
    await expect(backRow.getByTestId("weight-time")).toHaveCount(0);
  });

  await test.step("editing the weight and the note keeps the time it was taken", async () => {
    const before = (await stored()).find((e) => e.weight === 80.4)!;
    await todayRow.getByRole("button", { name: /menu|more|⋯/i }).click();
    await page.getByRole("menuitem", { name: "Edit" }).click();
    await page.getByTestId("weight-note").fill("after breakfast");
    await page.getByRole("button", { name: "Save" }).click();
    await expect(page.getByText("Entry updated")).toBeVisible();

    const after = (await stored()).find((e) => e.note === "after breakfast")!;
    expect(after.id).not.toBe(before.id);
    expect(after.recordedAt).toBe(before.recordedAt);
    await expect(log.getByTestId("weight-note-cell").filter({ hasText: "after breakfast" })).toBeVisible();
  });

  await test.step("a new entry through the drawer gets a note and a time of its own", async () => {
    await page.getByRole("button", { name: "Log weight" }).first().click();
    await page.getByTestId("weight-note").fill("evening");
    // Another entry for today asks before replacing the one already there.
    await page.getByRole("button", { name: "Save" }).click();
    await page.getByRole("button", { name: /replace/i }).click();
    await expect(page.getByText("Weight logged")).toBeVisible();

    const latest = (await stored()).find((e) => e.note === "evening")!;
    expect(latest.date).toBe(today);
    expect(latest.recordedAt).not.toBeNull();
  });
});
