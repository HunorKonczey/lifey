import { test, expect, type APIRequestContext } from "@playwright/test";
import { Client } from "pg";
import { CHAT_BASE, chatServiceIsUp } from "./support/environment";

/**
 * "Online" in the trainer's thread header (LIF-122, docs/chat/40-trainer-chat-plan.md section 22): the client - on the phone in
 * real life - holds a chat stream open, and the trainer sees the word next to the client's name; when the stream closes the
 * word goes after the server's grace (`lifey.chat.online-grace`, 15 s by default), not at once.
 *
 * The client's stream is a plain streaming `fetch` from the test process: the phone is not something Playwright can drive, and
 * all that matters to the server is an open `GET /chat/stream` with the client's token.
 *
 * Requires the real backend + Postgres, the chat service on :8081 and the web started with `NEXT_PUBLIC_CHAT_BASE_URL`
 * (the `web-chat` dev config) - same as trainer-chat.spec.ts, see e2e/README.md.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };

async function registerAndLogin(request: APIRequestContext, email: string, password: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password, firstName: "E2E", lastName: "Online" } });
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

/** Opens `GET /chat/stream` as `token` and keeps it open until the returned function is called. */
async function openStream(token: string): Promise<() => void> {
  const controller = new AbortController();
  const res = await fetch(`${CHAT_BASE}/chat/stream`, {
    headers: { Authorization: `Bearer ${token}`, Accept: "text/event-stream" },
    signal: controller.signal,
  });
  expect(res.ok).toBeTruthy();
  // Drain in the background so the connection stays open and the heartbeats do not back up.
  void (async () => {
    try {
      const reader = res.body!.getReader();
      while (!(await reader.read()).done) {
        /* keep reading */
      }
    } catch {
      /* aborted */
    }
  })();
  return () => controller.abort();
}

test.describe("Trainer web chat: online", () => {
  test.beforeAll(async ({ request }) => {
    test.skip(!(await chatServiceIsUp(request)), "requires the chat service on localhost:8081 - see e2e/README.md");
  });

  test("the thread header says Online while the client has the app open, and stops after the grace", async ({ page, request }) => {
    test.setTimeout(120_000);
    const runId = Date.now();
    const trainerEmail = `e2e-online-trainer-${runId}@example.com`;
    const clientEmail = `e2e-online-client-${runId}@example.com`;
    const password = "E2eOnline123!";

    const trainer = await registerAndLogin(request, trainerEmail, password);
    await grantTrainerRole(trainer.userId);
    const client = await registerAndLogin(request, clientEmail, password);
    // The roles ride in the JWT, so the trainer signs in again after the grant.
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
    await expect(page.getByPlaceholder("Message…")).toBeVisible();

    const online = page.getByTestId("chat-peer-online");
    await expect(online, "nobody has the app open yet").toHaveCount(0);

    const closeClientStream = await openStream(client.accessToken);
    await expect(online).toBeVisible({ timeout: 15_000 });
    await expect(online).toContainText("Online");

    closeClientStream();
    // Not at once: the server notices a closed socket at its next heartbeat write (up to 20 s) and then waits out its grace (15 s).
    await expect(online).toBeHidden({ timeout: 70_000 });
  });
  test("a client who turns the switch off disappears from the trainer's header while still connected, and comes back when it is on", async ({ page, request }) => {
    test.setTimeout(180_000);
    const runId = Date.now();
    const trainerEmail = `e2e-hide-trainer-${runId}@example.com`;
    const clientEmail = `e2e-hide-client-${runId}@example.com`;
    const password = "E2eHide123!";

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
    await expect(page.getByPlaceholder("Message…")).toBeVisible();

    const setVisible = async (visible: boolean) => {
      const auth = { Authorization: `Bearer ${client.accessToken}` };
      const settings = await (await request.get(`${API_BASE}/settings`, { headers: auth })).json();
      const res = await request.put(`${API_BASE}/settings`, { headers: auth, data: { ...settings, chatOnlineVisible: visible } });
      expect(res.ok(), await res.text()).toBeTruthy();
    };

    const online = page.getByTestId("chat-peer-online");
    const closeClientStream = await openStream(client.accessToken);
    try {
      await expect(online).toBeVisible({ timeout: 15_000 });

      // The stream stays open: the person is still connected, only no longer shown. The server notices the saved setting on
      // its next reconcile tick (30 s by default), not at once.
      await setVisible(false);
      await expect(online).toBeHidden({ timeout: 60_000 });

      await setVisible(true);
      await expect(online).toBeVisible({ timeout: 60_000 });
    } finally {
      closeClientStream();
    }
  });
});
