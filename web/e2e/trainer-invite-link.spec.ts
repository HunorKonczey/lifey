import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { Client } from "pg";

/**
 * A trainer's shareable join link and the reminder for a pending invite (LIF-103): the trainer makes a link on the invites
 * page, a visitor opens it, signs in and is brought back to accept, the spent link is dead; a pending email invite can be
 * reminded once its cooldown has passed.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2eInviteLink123!";

async function registerAndLogin(request: APIRequestContext, email: string, firstName = "E2E") {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName, lastName: "Invite" } });
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

async function ageInvite(inviteId: number, hours: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query("update trainer_clients set created_at = created_at - ($2 || ' hours')::interval where id = $1", [inviteId, String(hours)]);
  } finally {
    await db.end();
  }
}

/** Fills the sign-in form; `fromHere` keeps the page the visitor is on (it carries `?next=`) instead of opening a bare /login. */
async function signIn(page: Page, email: string, fromHere = false) {
  if (!fromHere) await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
}

test("a join link makes a visitor the trainer's client once; a pending invite can be reminded after its cooldown", async ({ browser, page, request }) => {
  const runId = Date.now();
  const trainerEmail = `e2e-link-trainer-${runId}@example.com`;
  const joinerEmail = `e2e-link-joiner-${runId}@example.com`;
  const inviteeEmail = `e2e-link-invitee-${runId}@example.com`;

  let trainerToken = "";
  let joinerId = 0;
  let joinUrl = "";

  await test.step("a trainer, a user who will use the link, and one more user to invite by email", async () => {
    const trainer = await registerAndLogin(request, trainerEmail, "Kata");
    await grantTrainerRole(trainer.userId);
    // The roles ride in the JWT, so the grant only shows in a token issued after it.
    trainerToken = (await (await request.post(`${API_BASE}/auth/login`, { data: { email: trainerEmail, password: PASSWORD } })).json()).accessToken;
    joinerId = (await registerAndLogin(request, joinerEmail)).userId;
    await registerAndLogin(request, inviteeEmail);
  });

  await signIn(page, trainerEmail);
  await page.waitForURL(/dashboard|admin/);
  await page.goto("/admin/invites");

  await test.step("the trainer makes a link and sees it once, ready to copy", async () => {
    await page.getByTestId("invite-link-create").click();
    const field = page.getByTestId("invite-link-created").getByRole("textbox", { name: "Join link" });
    await expect(field).toHaveValue(/\/join\/[A-Za-z0-9_-]+$/);
    joinUrl = await field.inputValue();
    await expect(page.getByTestId("invite-link-row")).toHaveCount(1);
  });

  await test.step("a visitor who is not signed in sees who is inviting, signs in and is brought back to accept", async () => {
    const visitor = await (await browser.newContext()).newPage();
    await visitor.goto(joinUrl);
    await expect(visitor.getByRole("heading", { name: "Kata Invite invited you" })).toBeVisible();

    await visitor.getByTestId("join-sign-in").click();
    await expect(visitor).toHaveURL(/\/login\?next=%2Fjoin%2F/);
    await signIn(visitor, joinerEmail, true);
    await expect(visitor).toHaveURL(joinUrl);

    await visitor.getByTestId("join-accept").click();
    await visitor.waitForURL(/dashboard/);

    const clients: Array<{ clientId: number }> = await (await request.get(`${API_BASE}/trainer/clients`, { headers: { Authorization: `Bearer ${trainerToken}` } })).json();
    expect(clients.map((c) => c.clientId)).toContain(joinerId);
    await visitor.context().close();
  });

  await test.step("the spent link is dead, and the trainer's list no longer shows it", async () => {
    const stranger = await (await browser.newContext()).newPage();
    await stranger.goto(joinUrl);
    await expect(stranger.getByTestId("join-invalid")).toBeVisible();
    await stranger.context().close();

    await page.reload();
    await expect(page.getByTestId("invite-link-row")).toHaveCount(0);
  });

  await test.step("a link the trainer takes back stops working", async () => {
    await page.getByTestId("invite-link-create").click();
    const field = page.getByTestId("invite-link-created").getByRole("textbox", { name: "Join link" });
    const second = await field.inputValue();
    await page.getByTestId("invite-link-row").getByRole("button", { name: "Revoke" }).click();
    await expect(page.getByTestId("invite-link-row")).toHaveCount(0);

    const visitor = await (await browser.newContext()).newPage();
    await visitor.goto(second);
    await expect(visitor.getByTestId("join-invalid")).toBeVisible();
    await visitor.context().close();
  });

  let inviteId = 0;
  await test.step("an email invite can't be reminded the moment it is sent", async () => {
    const inviteRes = await request.post(`${API_BASE}/trainer/invites`, { headers: { Authorization: `Bearer ${trainerToken}` }, data: { email: inviteeEmail } });
    expect(inviteRes.ok(), await inviteRes.text()).toBeTruthy();
    inviteId = (await inviteRes.json()).id;

    await page.reload();
    const row = page.getByTestId("invite-row").filter({ hasText: inviteeEmail });
    await expect(row).toBeVisible();
    await expect(row.getByTestId("invite-remind")).toBeDisabled();

    const tooSoon = await request.post(`${API_BASE}/trainer/invites/${inviteId}/remind`, { headers: { Authorization: `Bearer ${trainerToken}` } });
    expect(tooSoon.status()).toBe(429);
  });

  await test.step("after the cooldown a reminder goes out, and the next one has to wait again", async () => {
    await ageInvite(inviteId, 5);
    await page.reload();
    const row = page.getByTestId("invite-row").filter({ hasText: inviteeEmail });
    await expect(row.getByTestId("invite-remind")).toBeEnabled();

    await row.getByTestId("invite-remind").click();
    await expect(page.getByText("Reminder sent")).toBeVisible();
    await expect(row.getByTestId("invite-remind")).toBeDisabled();
    await expect(row).toContainText("reminded");

    const pending: Array<{ id: number; lastRemindedAt: string | null }> = await (await request.get(`${API_BASE}/trainer/invites`, { headers: { Authorization: `Bearer ${trainerToken}` } })).json();
    expect(pending.find((i) => i.id === inviteId)?.lastRemindedAt).not.toBeNull();
  });
});
