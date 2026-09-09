import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { Client } from "pg";

/**
 * The Prompt 9 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "a Studio→Starter downgrade with 8 clients enters `OVER_LIMIT`, and
 * archiving down to 5 clears it without any data disappearing from the
 * archived clients' pages." §4.1 (D-M12) is what's under test: archiving is
 * the trainer's own choice, one client at a time — nothing is auto-removed,
 * and the archived client keeps everything (`ScheduleCancellationListener`
 * cancels only *future* schedules/assignments; `TrainerAccessServiceImpl
 * .revoke` never touches the client's own data, confirmed by reading it
 * before writing this test).
 *
 * Same conventions as `billing-blocked-dialog.spec.ts`: self-contained
 * accounts, `loginThroughUi`, requires the backend started with
 * `BILLING_ENABLED=true` (probed via `billingIsEnabled`, skipped otherwise —
 * `OVER_LIMIT` only exists once `SeatLimitServiceImpl` is actually enforcing
 * anything, see `billingGate.ts`'s landed notes).
 *
 * Requires the real backend + Postgres running on localhost:8080/5432 (see
 * playwright.config.ts, which only auto-starts the Next.js dev server).
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2eOverLimit123!";

async function billingIsEnabled(request: APIRequestContext): Promise<boolean> {
  const email = `e2e-overlimit-probe-${Date.now()}@example.com`;
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password: PASSWORD, firstName: "Probe", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  const { accessToken } = await loginRes.json();
  const entRes = await request.get(`${API_BASE}/me/entitlements`, { headers: { Authorization: `Bearer ${accessToken}` } });
  const entitlement: { source: string } = await entRes.json();
  return entitlement.source === "NONE";
}

async function register(request: APIRequestContext, email: string): Promise<{ userId: number; accessToken: string }> {
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password: PASSWORD, firstName: "E2E", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();

  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  const { accessToken }: { accessToken: string } = await loginRes.json();

  return { userId: user.id, accessToken };
}

/** A "Studio→Starter downgrade" — an ACTIVE STARTER subscription (max 5) is what matters; how the trainer got there isn't. */
async function grantTrainerRoleAndStarter(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [userId]);
    await db.query(
      "insert into subscription (user_id, provider, status, plan, current_period_end, cancel_at_period_end, created_at, updated_at) " +
        "values ($1, 'STRIPE', 'ACTIVE', 'STARTER', now() + interval '20 days', false, now(), now())",
      [userId],
    );
  } finally {
    await db.end();
  }
}

async function addActiveClient(request: APIRequestContext, trainerId: number, email: string) {
  const { userId: clientId, accessToken } = await register(request, email);
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query(
      "insert into trainer_clients (trainer_id, client_id, status, expires_at, responded_at) " +
        "values ($1, $2, 'ACTIVE', now() + interval '1 day', now())",
      [trainerId, clientId],
    );
  } finally {
    await db.end();
  }
  return { clientId, accessToken };
}

/** Dismissed once per session by design (`admin/page.tsx`'s `MODAL_SEEN_KEY`)
 *  — unrelated to this prompt, but its full-screen backdrop otherwise
 *  intercepts every click on the client grid underneath it. */
async function skipFirstVisitModal(page: Page) {
  await page.addInitScript(() => sessionStorage.setItem("lifey-admin-client-modal-shown", "1"));
}

async function loginThroughUi(page: Page, email: string) {
  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL("**/dashboard");
}

test.describe("Over-limit archiving flow (66 §4.1, D-M12)", () => {
  test("8 clients on a 5-seat plan enters OVER_LIMIT; archiving down to 5 clears it, and the archived client's own data is untouched", async ({
    page,
    request,
  }) => {
    test.skip(!(await billingIsEnabled(request)), "requires the backend started with BILLING_ENABLED=true — see file header");

    const trainerEmail = `e2e-overlimit-trainer-${Date.now()}@example.com`;
    const { userId: trainerId } = await register(request, trainerEmail);
    await grantTrainerRoleAndStarter(trainerId);

    const clients: Array<{ clientId: number; accessToken: string; email: string }> = [];
    for (let i = 0; i < 8; i++) {
      const email = `e2e-overlimit-client-${Date.now()}-${i}@example.com`;
      const { clientId, accessToken } = await addActiveClient(request, trainerId, email);
      clients.push({ clientId, accessToken, email });
    }

    // The client at index 0 will be one of the archived ones — give it a real
    // weight entry to prove archiving never touches the client's own data.
    const weightRes = await request.post(`${API_BASE}/weights`, {
      headers: { Authorization: `Bearer ${clients[0].accessToken}` },
      data: { date: new Date().toISOString().slice(0, 10), weight: 82.5 },
    });
    expect(weightRes.ok(), await weightRes.text()).toBeTruthy();

    await skipFirstVisitModal(page);
    await loginThroughUi(page, trainerEmail);
    await page.goto("/admin");

    await test.step("the banner counts down: 8 on a 5-seat plan means 3 to archive", async () => {
      await expect(page.getByTestId("admin-billing-banner")).toHaveAttribute("data-banner-kind", "overLimit");
      await expect(page.getByText("8 / 5 active clients")).toBeVisible();
      await expect(page.getByText("Archive 3 clients")).toBeVisible();
    });

    await test.step("every client card offers the inline Archive action, not just some", async () => {
      await expect(page.getByTestId("archive-client-inline")).toHaveCount(8);
    });

    await test.step("archiving three clients (any three — D-M12: no ordering is implied) clears OVER_LIMIT", async () => {
      // The first one archived is specifically clients[0] (the one with the
      // seeded weight entry), so the later "data survives" check is provably
      // about an *archived* client, not an incidental survivor. The other two
      // are whichever the list shows first — deliberately unordered, since
      // D-M12 rejects any implied "these ones should go" heuristic.
      const firstCard = page.locator(`[data-client-email="${clients[0].email}"]`);
      await firstCard.getByTestId("archive-client-inline").click();
      await expect(page.getByTestId("archive-client-confirm")).toBeVisible();
      await page.getByTestId("archive-client-confirm-submit").click();
      await expect(page.getByTestId("archive-client-confirm")).not.toBeVisible();
      await expect(page.getByTestId("client-card")).toHaveCount(7);

      for (let i = 0; i < 2; i++) {
        await page.getByTestId("archive-client-inline").first().click();
        await expect(page.getByTestId("archive-client-confirm")).toBeVisible();
        await page.getByTestId("archive-client-confirm-submit").click();
        await expect(page.getByTestId("archive-client-confirm")).not.toBeVisible();
        await expect(page.getByTestId("client-card")).toHaveCount(7 - i - 1);
      }
    });

    await test.step("the banner clears entirely once back at 5, and the inline archive action goes with it", async () => {
      await expect(page.getByTestId("admin-billing-banner")).not.toBeVisible();
      await expect(page.getByTestId("archive-client-inline")).toHaveCount(0);
      await expect(page.getByTestId("client-card")).toHaveCount(5);
    });

    await test.step("the archived client (index 0) keeps their own data — nothing disappeared", async () => {
      const weightsRes = await request.get(`${API_BASE}/weights`, {
        headers: { Authorization: `Bearer ${clients[0].accessToken}` },
      });
      expect(weightsRes.ok(), await weightsRes.text()).toBeTruthy();
      const weights: Array<{ weight: number }> = await weightsRes.json();
      expect(weights.some((w) => w.weight === 82.5)).toBe(true);
    });
  });
});
