import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { Client } from "pg";

/**
 * The Prompt 10 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "component test that step 2 ticks on *accepted*, not on *sent*." This
 * project has no component-rendering test infrastructure (confirmed before
 * writing anything), so `onboardingChecklist.test.ts` covers that exact rule
 * — and every other step's logic — as a pure-function test instead. This file
 * covers the other half: `TrainerOnboardingChecklist` actually wired into
 * `/admin` with real data, driven through the real UI.
 *
 * Unlike Prompts 7–9, this one does **not** need `BILLING_ENABLED=true` — the
 * checklist gates purely on `trainer.status === "TRIALING"`, and (per
 * Prompt 5's landed notes, re-confirmed while writing this) `trainer.status`
 * is populated from the real subscription row regardless of the
 * `lifey.billing.enabled` rollback switch; `buildTrainerBlock` runs before
 * that flag is even checked. Runs against this project's normal default
 * backend.
 *
 * Step 5 ("first message sent") isn't exercised here — chat is a separate
 * service (`backend/CLAUDE.md`: `chat_conversations`/`chat_messages` belong
 * to `lifey-chat`, not this monolith's database), not running in this local
 * dev setup (no `chat` entry in `.claude/launch.json`), and this suite's own
 * `trainer-chat.spec.ts` is a known, pre-existing, unrelated timeout in this
 * environment. Step 5's logic is covered by the pure-function test instead;
 * this file only proves the checklist's rendering, the profile self-report,
 * and steps 2–4's real data wiring.
 *
 * Requires the real backend + Postgres running on localhost:8080/5432 (see
 * playwright.config.ts, which only auto-starts the Next.js dev server).
 */

const API_BASE = "http://localhost:8080/api/v1";
const DB_CONFIG = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
const PASSWORD = "E2eOnboarding123!";

async function register(request: APIRequestContext, email: string): Promise<number> {
  const registerRes = await request.post(`${API_BASE}/auth/register`, {
    data: { email, password: PASSWORD, firstName: "E2E", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();
  return user.id;
}

/** Logged in only after the role grant — a JWT's `roles` claim is fixed at
 *  mint time (found the hard way in Prompt 8's own landed notes). */
async function login(request: APIRequestContext, email: string): Promise<string> {
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  const { accessToken }: { accessToken: string } = await loginRes.json();
  return accessToken;
}

async function grantTrainerRoleAndTrial(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [userId]);
    await db.query(
      "insert into subscription (user_id, provider, status, plan, trial_ends_at, cancel_at_period_end, created_at, updated_at) " +
        "values ($1, 'STRIPE', 'TRIALING', 'PRO', now() + interval '10 days', false, now(), now())",
      [userId],
    );
  } finally {
    await db.end();
  }
}

async function addActiveClient(request: APIRequestContext, trainerId: number, email: string) {
  const clientId = await register(request, email);
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
  return clientId;
}

/** Dismissed once per session by design (`admin/page.tsx`'s `MODAL_SEEN_KEY`)
 *  — unrelated to this prompt, but its full-screen backdrop otherwise
 *  intercepts every click on the page underneath it. */
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

function step(page: Page, id: string) {
  return page.getByTestId(`onboarding-step-${id}`);
}

test.describe("TrainerOnboardingChecklist (66 §5)", () => {
  test("shows for a TRIALING trainer; step 2 ticks only once an invite is ACCEPTED, not merely sent", async ({ page, request }) => {
    const trainerEmail = `e2e-onboarding-${Date.now()}@example.com`;
    const trainerId = await register(request, trainerEmail);
    await grantTrainerRoleAndTrial(trainerId);
    const accessToken = await login(request, trainerEmail);

    await skipFirstVisitModal(page);
    await loginThroughUi(page, trainerEmail);
    await page.goto("/admin");

    await expect(page.getByTestId("trainer-onboarding-checklist")).toBeVisible();
    await expect(step(page, "profile")).toHaveAttribute("data-step-done", "false");
    await expect(step(page, "inviteAccepted")).toHaveAttribute("data-step-done", "false");

    // A merely-*sent* invite (PENDING, not yet accepted) must not tick step 2 —
    // GET /trainer/clients only ever returns ACTIVE relationships, so a
    // pending one is invisible to the checklist by construction.
    const pendingEmail = `e2e-onboarding-pending-${Date.now()}@example.com`;
    await register(request, pendingEmail); // the invite target must already have an account
    const sendRes = await request.post(`${API_BASE}/trainer/invites`, {
      headers: { Authorization: `Bearer ${accessToken}` },
      data: { email: pendingEmail },
    });
    expect(sendRes.ok(), await sendRes.text()).toBeTruthy();
    await page.reload();
    await expect(step(page, "inviteAccepted")).toHaveAttribute("data-step-done", "false");

    const clientId = await addActiveClient(request, trainerId, `e2e-onboarding-client-${Date.now()}@example.com`);
    await page.reload();
    await expect(step(page, "inviteAccepted")).toHaveAttribute("data-step-done", "true");

    await test.step("step 1 (profile) is self-reported by clicking its checkbox", async () => {
      await step(page, "profile").getByRole("button").click();
      await expect(step(page, "profile")).toHaveAttribute("data-step-done", "true");
      // Persists across a reload (localStorage, not component state).
      await page.reload();
      await expect(step(page, "profile")).toHaveAttribute("data-step-done", "true");
    });

    await test.step("step 3 ticks once a workout template exists", async () => {
      await expect(step(page, "templateCreated")).toHaveAttribute("data-step-done", "false");
      const exercisesRes = await request.get(`${API_BASE}/exercises`, { headers: { Authorization: `Bearer ${accessToken}` } });
      const exercises: Array<{ id: number }> = await exercisesRes.json();
      const templateRes = await request.post(`${API_BASE}/workout-templates`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        data: { name: `E2E Onboarding Template ${Date.now()}`, exercises: [{ exerciseId: exercises[0].id, targetSets: 3 }] },
      });
      expect(templateRes.ok(), await templateRes.text()).toBeTruthy();
      const template: { id: number } = await templateRes.json();

      await page.reload();
      await expect(step(page, "templateCreated")).toHaveAttribute("data-step-done", "true");

      await test.step("step 4 ticks once that template is assigned to a client", async () => {
        await expect(step(page, "contentAssigned")).toHaveAttribute("data-step-done", "false");
        const assignRes = await request.post(`${API_BASE}/trainer/assignments`, {
          headers: { Authorization: `Bearer ${accessToken}` },
          data: { clientIds: [clientId], contentType: "TEMPLATE", sourceId: template.id },
        });
        expect(assignRes.ok(), await assignRes.text()).toBeTruthy();

        await page.reload();
        await expect(step(page, "contentAssigned")).toHaveAttribute("data-step-done", "true");
      });
    });

    // Still not dismissible — step 5 (chat) is deliberately left undone in
    // this environment (see file header), so completion, and the dismiss
    // button that only appears once complete, are out of reach here.
    await expect(page.getByTestId("trainer-onboarding-checklist").getByRole("button", { name: "Dismiss" })).toHaveCount(0);
  });

  test("never shows for a non-TRIALING trainer (e.g. ACTIVE)", async ({ page, request }) => {
    const trainerEmail = `e2e-onboarding-active-${Date.now()}@example.com`;
    const trainerId = await register(request, trainerEmail);
    const db = new Client(DB_CONFIG);
    await db.connect();
    try {
      await db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [trainerId]);
      await db.query(
        "insert into subscription (user_id, provider, status, plan, current_period_end, cancel_at_period_end, created_at, updated_at) " +
          "values ($1, 'STRIPE', 'ACTIVE', 'STARTER', now() + interval '20 days', false, now(), now())",
        [trainerId],
      );
    } finally {
      await db.end();
    }

    await loginThroughUi(page, trainerEmail);
    await page.goto("/admin");
    await expect(page.getByTestId("trainer-onboarding-checklist")).not.toBeVisible();
  });
});
