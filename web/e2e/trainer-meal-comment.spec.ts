import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { Client } from "pg";

/**
 * The trainer's comment on a client's meal (LIF-144): written under the meal on the client's nutrition tab, edited, and
 * removed; the client sees it on their own nutrition page and in the API the apps pull from.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2eMealComment123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Meal" } });
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

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|admin/);
}

test("a trainer comments on a client's meal, edits and removes it, and the client sees it on the web", async ({ browser, page, request }) => {
  const runId = Date.now();
  const trainerEmail = `e2e-mealc-trainer-${runId}@example.com`;
  const clientEmail = `e2e-mealc-client-${runId}@example.com`;

  let clientId = 0;
  let clientAuth: Record<string, string> = {};
  let mealId = 0;

  await test.step("a trainer, a connected client and one meal the client logged today", async () => {
    const trainer = await registerAndLogin(request, trainerEmail);
    await grantTrainerRole(trainer.userId);
    // The roles ride in the JWT, so the grant only shows in a token issued after it.
    const trainerToken: string = (await (await request.post(`${API_BASE}/auth/login`, { data: { email: trainerEmail, password: PASSWORD } })).json()).accessToken;

    const client = await registerAndLogin(request, clientEmail);
    clientId = client.userId;
    clientAuth = { Authorization: `Bearer ${client.accessToken}` };
    const invite: { id: number } = await (await request.post(`${API_BASE}/trainer/invites`, { headers: { Authorization: `Bearer ${trainerToken}` }, data: { email: clientEmail } })).json();
    const respondRes = await request.post(`${API_BASE}/trainer-invites/${invite.id}/respond`, { headers: clientAuth, data: { accept: true } });
    expect(respondRes.ok(), await respondRes.text()).toBeTruthy();

    const foodRes = await request.post(`${API_BASE}/foods`, { headers: clientAuth, data: { name: `Oats ${runId}`, caloriesPer100g: 370, proteinPer100g: 13, carbsPer100g: 60, fatPer100g: 7, hidden: false } });
    expect(foodRes.ok(), await foodRes.text()).toBeTruthy();
    const mealRes = await request.post(`${API_BASE}/meals`, {
      headers: clientAuth,
      data: { dateTime: new Date().toISOString(), mealType: "BREAKFAST", entries: [{ foodId: (await foodRes.json()).id, quantityInGrams: 80 }] },
    });
    expect(mealRes.ok(), await mealRes.text()).toBeTruthy();
    mealId = (await mealRes.json()).id;
  });

  const storedComment = async () => {
    const meals: Array<{ id: number; trainerComment?: string | null }> = await (await request.get(`${API_BASE}/meals`, { headers: clientAuth })).json();
    return meals.find((m) => m.id === mealId)?.trainerComment ?? null;
  };

  await signIn(page, trainerEmail);
  await page.goto(`/admin/clients/${clientId}`);
  await page.getByRole("tab", { name: "Nutrition" }).click();

  await test.step("the trainer adds a comment under the meal", async () => {
    await page.getByTestId("meal-comment-add").click();
    await page.getByLabel("Your comment").fill("Good start. Add a piece of fruit.");
    await page.getByRole("button", { name: "Save" }).click();
    await expect(page.getByText("Comment saved — your client was notified")).toBeVisible();
    await expect(page.getByTestId("meal-comment-text")).toHaveText("Good start. Add a piece of fruit.");
    expect(await storedComment()).toBe("Good start. Add a piece of fruit.");
  });

  await test.step("the client sees it on their own nutrition page", async () => {
    const clientPage = await (await browser.newContext()).newPage();
    await signIn(clientPage, clientEmail);
    await clientPage.goto("/nutrition");
    await expect(clientPage.getByTestId("meal-trainer-comment")).toContainText("Good start. Add a piece of fruit.");
    await expect(clientPage.getByTestId("meal-trainer-comment")).toContainText("Trainer comment");
    await clientPage.context().close();
  });

  await test.step("editing it keeps one comment and does not claim a second notification", async () => {
    await page.getByRole("button", { name: "Edit", exact: true }).click();
    await page.getByLabel("Your comment").fill("Good start. Add a piece of fruit and some nuts.");
    await page.getByRole("button", { name: "Save" }).click();
    await expect(page.getByText("Comment saved", { exact: true })).toBeVisible();
    await expect(page.getByTestId("meal-comment-text")).toHaveText("Good start. Add a piece of fruit and some nuts.");
    expect(await storedComment()).toBe("Good start. Add a piece of fruit and some nuts.");
  });

  await test.step("removing it, behind a confirmation, clears it for the client too", async () => {
    await page.getByRole("button", { name: "Delete", exact: true }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Delete", exact: true }).click();
    await expect(page.getByTestId("meal-comment-add")).toBeVisible();
    await expect(page.getByTestId("meal-comment-text")).toHaveCount(0);
    expect(await storedComment()).toBeNull();
  });
});
