import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";

/**
 * Trainer web chat (docs/chat/40-trainer-chat-plan.md I3): the trainer opens a
 * thread from the client detail page, sends a message, and the client — who in
 * real life is on mobile — receives it. The client side is API-simulated here,
 * exactly like the accept step in trainer-flow.spec.ts, because there is no
 * Flutter app to drive from Playwright.
 *
 * Relationship setup runs through the API to keep the assertions on the chat
 * itself; only the chat interaction goes through the UI.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the
 * other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = {
  host: "localhost",
  port: 5432,
  database: "lifey",
  user: "lifey",
  password: "lifey",
};

async function registerAndLogin(request: APIRequestContext, email: string, password: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password, firstName: "E2E", lastName: "Chat" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();

  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  const { accessToken }: { accessToken: string } = await loginRes.json();

  return { userId: user.id, accessToken };
}

/** ROLE_TRAINER has no grant API — see trainer-flow.spec.ts for the why. */
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

test.describe("Trainer web chat", () => {
  test("opens a thread from the client page, sends a message, client receives it", async ({ page, request }) => {
    const runId = Date.now();
    const trainerEmail = `e2e-chat-trainer-${runId}@example.com`;
    const trainerPassword = "E2eTrainer123!";
    const clientEmail = `e2e-chat-client-${runId}@example.com`;
    const clientPassword = "E2eClient123!";
    const messageBody = `Holnap 17:00 jó? ${runId}`;

    let trainerToken = "";
    let clientToken = "";

    await test.step("register both accounts and link them as trainer and client", async () => {
      const trainer = await registerAndLogin(request, trainerEmail, trainerPassword);
      await grantTrainerRole(trainer.userId);
      clientToken = (await registerAndLogin(request, clientEmail, clientPassword)).accessToken;

      // The pre-grant token's `roles` claim is stale — JWTs aren't reissued.
      const reLoginRes = await request.post(`${API_BASE}/auth/login`, {
        data: { email: trainerEmail, password: trainerPassword },
      });
      expect(reLoginRes.ok()).toBeTruthy();
      trainerToken = (await reLoginRes.json()).accessToken;

      const inviteRes = await request.post(`${API_BASE}/trainer/invites`, {
        headers: { Authorization: `Bearer ${trainerToken}` },
        data: { email: clientEmail },
      });
      expect(inviteRes.ok(), await inviteRes.text()).toBeTruthy();
      const invite: { id: number } = await inviteRes.json();

      const respondRes = await request.post(`${API_BASE}/trainer-invites/${invite.id}/respond`, {
        headers: { Authorization: `Bearer ${clientToken}` },
        data: { accept: true },
      });
      expect(respondRes.ok(), await respondRes.text()).toBeTruthy();
    });

    await test.step("trainer logs in through the real UI", async () => {
      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(trainerEmail);
      await page.getByPlaceholder("••••••••").fill(trainerPassword);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL("**/dashboard");
    });

    await test.step("the Message button on the client page opens the thread", async () => {
      const clientsRes = await request.get(`${API_BASE}/trainer/clients`, {
        headers: { Authorization: `Bearer ${trainerToken}` },
      });
      expect(clientsRes.ok()).toBeTruthy();
      const clients: Array<{ clientId: number; clientEmail: string }> = await clientsRes.json();
      const client = clients.find((c) => c.clientEmail === clientEmail);
      expect(client, "expected the accepted client on the trainer's list").toBeTruthy();

      await page.goto(`/admin/clients/${client!.clientId}`);
      await page.getByRole("button", { name: "Message" }).click();
      await page.waitForURL(/\/admin\/chat\?c=\d+/);
      await expect(page.getByPlaceholder("Message…")).toBeVisible();
    });

    await test.step("Enter sends the message and the bubble appears in the thread", async () => {
      const composer = page.getByPlaceholder("Message…");
      await composer.fill(messageBody);
      await composer.press("Enter");

      // `exact` keeps this on the bubble: the conversation row shows the same
      // text behind a "You: " prefix.
      await expect(page.getByText(messageBody, { exact: true })).toBeVisible();
      await expect(page.getByTitle("Sent")).toBeVisible();
      await expect(page.getByText(`You: ${messageBody}`)).toBeVisible();

      // Not just an optimistic bubble: it survives a reload, i.e. it was stored.
      await page.reload();
      await expect(page.getByText(messageBody, { exact: true })).toBeVisible();
    });

    await test.step("the message reaches the client's conversation list", async () => {
      const conversationsRes = await request.get(`${API_BASE}/chat/conversations`, {
        headers: { Authorization: `Bearer ${clientToken}` },
      });
      expect(conversationsRes.ok(), await conversationsRes.text()).toBeTruthy();
      const { items }: { items: Array<{ unreadCount: number; lastMessage: { body: string } | null }> } =
        await conversationsRes.json();

      expect(items).toHaveLength(1);
      expect(items[0].lastMessage?.body).toBe(messageBody);
      expect(items[0].unreadCount).toBe(1);
    });

    await test.step("the trainer's own message is never unread for them", async () => {
      const conversationsRes = await request.get(`${API_BASE}/chat/conversations`, {
        headers: { Authorization: `Bearer ${trainerToken}` },
      });
      expect(conversationsRes.ok()).toBeTruthy();
      const { items }: { items: Array<{ unreadCount: number }> } = await conversationsRes.json();
      expect(items[0].unreadCount).toBe(0);
    });
  });
});
