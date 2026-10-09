import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { Client } from "pg";

/**
 * The Prompt 3 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "Playwright as a super admin; a rejected request cannot be re-opened by the
 * user without a new submission." Same conventions as e2e/trainer-flow.spec.ts —
 * fully self-contained accounts; ROLE_SUPER_ADMIN has no grant API by design
 * (docs/personal_trainer/03-backend-terv.md), so it's granted via a direct DB
 * write, the same kind of one-off a real deployment does by hand.
 *
 * Requires the real backend + Postgres running on localhost:8080/5432 (see
 * playwright.config.ts, which only auto-starts the Next.js dev server).
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
    data: { email, password, firstName: "E2E", lastName: "Test" },
  });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const user: { id: number } = await registerRes.json();

  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  const { accessToken }: { accessToken: string } = await loginRes.json();

  return { userId: user.id, accessToken };
}

async function grantSuperAdminRole(userId: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query(
      "insert into user_roles (user_id, role) values ($1, 'ROLE_SUPER_ADMIN') on conflict do nothing",
      [userId],
    );
  } finally {
    await db.end();
  }
}

/**
 * Opens the queue and returns the row of this applicant. The queue shows 20 pending requests a page, oldest first, so on a
 * database that has collected requests from earlier runs the new one is on a later page: page forward until it is there
 * (LIF-143). Fails with the page it gave up on if the row never shows up.
 */
async function openRequestRow(page: Page, applicantEmail: string) {
  await page.goto("/superadmin/trainer-requests");
  const rows = page.getByTestId("trainer-request-row");
  const row = rows.filter({ hasText: applicantEmail });
  const next = page.getByRole("button", { name: "Next page" });
  for (let pageNumber = 1; ; pageNumber++) {
    await expect(rows.first()).toBeVisible();
    if ((await row.count()) > 0) return row;
    // The pager only exists when there is more than one page, and its arrow is disabled on the last.
    if ((await next.count()) === 0 || !(await next.isEnabled())) {
      throw new Error(`no pending request of ${applicantEmail} in the queue (looked at ${pageNumber} page(s))`);
    }
    await next.click();
    await expect(page.getByText(new RegExp("^" + (pageNumber + 1) + " / [0-9]+$"))).toBeVisible();
  }
}

/**
 * The reject test ends by submitting a fresh request on purpose, and nothing ever decides it. Left alone it would stay
 * PENDING in the dev database and every run would add one more to the queue — resolve it directly, like the other specs do.
 */
async function rejectPendingRequestsOf(userId: number, decidedBy: number) {
  const db = new Client(DB_CONFIG);
  await db.connect();
  try {
    await db.query(
      "update trainer_request set status = 'REJECTED', decided_at = now(), decided_by = $2 where user_id = $1 and status = 'PENDING'",
      [userId, decidedBy],
    );
  } finally {
    await db.end();
  }
}

test.describe("Superadmin trainer-request queue", () => {
  test("approving a request from the queue grants the role and clears it from the list", async ({ page, request }) => {
    const runId = Date.now();
    const applicantEmail = `e2e-queue-approve-applicant-${runId}@example.com`;
    const applicantPassword = "E2eApplicant123!";
    const superAdminEmail = `e2e-queue-approve-admin-${runId}@example.com`;
    const superAdminPassword = "E2eSuperAdmin123!";

    const { accessToken: applicantToken } = await test.step("register the applicant and submit a request via the API", async () => {
      const applicant = await registerAndLogin(request, applicantEmail, applicantPassword);
      const createRes = await request.post(`${API_BASE}/trainer-requests`, {
        headers: { Authorization: `Bearer ${applicant.accessToken}` },
        data: { motivation: "Queue approve test", qualifications: "NASM-CPT, 6 years", clientCount: 5 },
      });
      expect(createRes.ok(), await createRes.text()).toBeTruthy();
      return applicant;
    });

    await test.step("register and promote a super admin, then log in through the real UI", async () => {
      const superAdmin = await registerAndLogin(request, superAdminEmail, superAdminPassword);
      await grantSuperAdminRole(superAdmin.userId);

      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(superAdminEmail);
      await page.getByPlaceholder("••••••••").fill(superAdminPassword);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL("**/dashboard");
    });

    await test.step("the request appears in the queue and can be approved", async () => {
      const row = await openRequestRow(page, applicantEmail);
      await expect(row).toBeVisible();
      await expect(row.getByTestId("request-qualifications")).toHaveText("NASM-CPT, 6 years");

      await row.getByRole("button", { name: "Approve" }).click();
      await page.getByTestId("trainer-request-confirm-decision").click();
      await expect(page.getByText("Request approved")).toBeVisible();
      await expect(row).not.toBeVisible();
    });

    await test.step("the applicant's own request now reads APPROVED", async () => {
      const meRes = await request.get(`${API_BASE}/trainer-requests/me`, {
        headers: { Authorization: `Bearer ${applicantToken}` },
      });
      expect(meRes.ok()).toBeTruthy();
      expect((await meRes.json()).status).toBe("APPROVED");
    });
  });

  test("rejecting a request lets the applicant submit a fresh one, but never re-opens the old one", async ({ page, request }) => {
    const runId = Date.now();
    const applicantEmail = `e2e-queue-reject-applicant-${runId}@example.com`;
    const applicantPassword = "E2eApplicant123!";
    const superAdminEmail = `e2e-queue-reject-admin-${runId}@example.com`;
    const superAdminPassword = "E2eSuperAdmin123!";
    let applicantId = 0;
    let superAdminId = 0;

    await test.step("register the applicant and submit a request via the API", async () => {
      const applicant = await registerAndLogin(request, applicantEmail, applicantPassword);
      applicantId = applicant.userId;
      const createRes = await request.post(`${API_BASE}/trainer-requests`, {
        headers: { Authorization: `Bearer ${applicant.accessToken}` },
        data: { motivation: "Queue reject test", clientCount: 3 },
      });
      expect(createRes.ok(), await createRes.text()).toBeTruthy();
    });

    await test.step("register and promote a super admin, then reject the request through the real UI", async () => {
      const superAdmin = await registerAndLogin(request, superAdminEmail, superAdminPassword);
      superAdminId = superAdmin.userId;
      await grantSuperAdminRole(superAdmin.userId);

      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(superAdminEmail);
      await page.getByPlaceholder("••••••••").fill(superAdminPassword);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL("**/dashboard");

      const row = await openRequestRow(page, applicantEmail);
      await expect(row).toBeVisible();
      // No qualifications were given: the card says so rather than leaving a blank.
      await expect(row.getByTestId("request-qualifications")).toHaveText("not given");
      await row.getByRole("button", { name: "Reject" }).click();
      await page.getByTestId("trainer-request-confirm-decision").click();
      await expect(page.getByText("Request rejected")).toBeVisible();
    });

    await test.step("the applicant sees the request form again, not a stuck/reopenable rejected state", async () => {
      await page.goto("/login");
      await page.getByPlaceholder("you@example.com").fill(applicantEmail);
      await page.getByPlaceholder("••••••••").fill(applicantPassword);
      await page.getByRole("button", { name: "Sign in" }).click();
      await page.waitForURL("**/dashboard");

      await page.goto("/admin/pending");
      await expect(page.getByText("Your previous request wasn't approved. You're welcome to submit a new one.")).toBeVisible();
      await expect(page.getByRole("heading", { name: "Become a Lifey trainer" })).toBeVisible();
    });

    await test.step("submitting a new request succeeds — there is no way to re-open the rejected one", async () => {
      await page.getByPlaceholder(/spreadsheets/).fill("Trying again after rejection");
      await page.getByRole("button", { name: "Submit request" }).click();
      await expect(page.getByText("We're reviewing your application")).toBeVisible();
    });

    await test.step("clean up: decide the fresh request so it does not pile up in the queue", async () => {
      await rejectPendingRequestsOf(applicantId, superAdminId);
    });
  });
});
