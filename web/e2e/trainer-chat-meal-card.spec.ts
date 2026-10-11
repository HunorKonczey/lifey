import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";
import { CHAT_BASE, chatServiceIsUp } from "./support/environment";

/**
 * A shared meal in the trainer's web thread (LIF-123, docs/chat/83 section 10): the client - on the phone in real life - sends a
 * MEAL card, and the trainer sees it as a tile: the meal, the calories, the macros, the fibre line (with the "some foods have no
 * figure" note when it is a lower bound) and what it was. Read-only: a meal has nothing to open.
 *
 * Requires the real backend + Postgres, the chat service on :8081 and the web started with `NEXT_PUBLIC_CHAT_BASE_URL`
 * (the `web-chat` dev config) - same as trainer-chat.spec.ts, see e2e/README.md.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };

async function registerAndLogin(request: APIRequestContext, email: string, password: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password, firstName: "E2E", lastName: "Meal" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  return { userId: user.id, accessToken: (await loginRes.json()).accessToken as string };
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

test.describe("Trainer web chat: meal card", () => {
  test.beforeAll(async ({ request }) => {
    test.skip(!(await chatServiceIsUp(request)), "requires the chat service on localhost:8081 - see e2e/README.md");
  });

  test("a shared meal is a tile in the thread, with the fibre note and what it was", async ({ page, request }) => {
    const runId = Date.now();
    const trainerEmail = `e2e-meal-trainer-${runId}@example.com`;
    const clientEmail = `e2e-meal-client-${runId}@example.com`;
    const password = "E2eMealCard123!";

    const trainer = await registerAndLogin(request, trainerEmail, password);
    await grantTrainerRole(trainer.userId);
    const client = await registerAndLogin(request, clientEmail, password);
    const trainerToken: string = (await (await request.post(`${API_BASE}/auth/login`, { data: { email: trainerEmail, password } })).json()).accessToken;
    const invite: { id: number } = await (await request.post(`${API_BASE}/trainer/invites`, { headers: { Authorization: `Bearer ${trainerToken}` }, data: { email: clientEmail } })).json();
    const respond = await request.post(`${API_BASE}/trainer-invites/${invite.id}/respond`, { headers: { Authorization: `Bearer ${client.accessToken}` }, data: { accept: true } });
    expect(respond.ok(), await respond.text()).toBeTruthy();

    await page.goto("/login");
    await page.getByPlaceholder("you@example.com").fill(trainerEmail);
    await page.getByPlaceholder("••••••••").fill(password);
    await page.getByRole("button", { name: "Sign in" }).click();
    await page.waitForURL("**/dashboard");
    await page.goto(`/admin/clients/${client.userId}`);
    await page.getByRole("button", { name: "Message" }).click();
    await page.waitForURL(/\/admin\/chat\?c=\d+/);
    const conversationId = Number(new URL(page.url()).searchParams.get("c"));
    await expect(page.getByPlaceholder("Message…")).toBeVisible();

    const sent = await request.post(`${CHAT_BASE}/chat/conversations/${conversationId}/messages`, {
      headers: { Authorization: `Bearer ${client.accessToken}` },
      data: {
        body: "Ez volt az ebédem",
        clientMessageId: `meal-${runId}`,
        card: {
          kind: "MEAL",
          occurredAt: new Date().toISOString(),
          meal: {
            mealType: "LUNCH",
            calories: 620,
            proteinGrams: 42,
            carbsGrams: 66,
            fatGrams: 18,
            fiberGrams: 7.5,
            sugarGrams: 9,
            fiberSugarPartial: true,
            itemCount: 5,
            itemNames: ["Chicken breast", "Rice", "Broccoli"],
          },
        },
      },
    });
    expect(sent.ok(), await sent.text()).toBeTruthy();

    const tile = page.getByRole("group", { name: /Meal:/ });
    await expect(tile).toBeVisible({ timeout: 20_000 });
    await expect(tile).toContainText("Meal");
    await expect(tile).toContainText("Lunch");
    await expect(tile).toContainText("620 kcal");
    await expect(tile).toContainText("Protein 42 g · Carbs 66 g · Fat 18 g");
    await expect(tile.getByTestId("chat-card-meal-fiber-sugar")).toHaveText("Fibre 7.5 g · Sugar 9 g · some foods have no figure");
    await expect(tile.getByTestId("chat-card-meal-foods")).toHaveText("Chicken breast, Rice, Broccoli +2");
    await expect(tile).toContainText("Ez volt az ebédem");

    await tile.screenshot({ path: process.env.MEAL_TILE_SHOT ?? "test-results/meal-tile.png" });

    // The conversation list previews it as a meal, not as an empty or deleted message.
    await expect(page.getByText("🍽️ Meal · Ez volt az ebédem")).toBeVisible();
  });
});
