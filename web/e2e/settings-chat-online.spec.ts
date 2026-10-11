import { test, expect, type APIRequestContext } from "@playwright/test";

/**
 * "Show when I'm online" on the web settings page (LIF-153): the switch is on by default, flipping it is saved by the real
 * backend, and it survives a reload. Requires the real backend + Postgres on localhost:8080/5432, same as the other specs here.
 */

const API_BASE = "http://localhost:8080/api/v1";
const PASSWORD = "E2eOnlineSwitch123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Switch" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  return (await loginRes.json()).accessToken as string;
}

test("the online switch is on by default, is saved by the backend and survives a reload", async ({ page, request }) => {
  const email = `e2e-online-switch-${Date.now()}@example.com`;
  const token = await registerAndLogin(request, email);
  const stored = async () =>
    ((await (await request.get(`${API_BASE}/settings`, { headers: { Authorization: `Bearer ${token}` } })).json()) as { chatOnlineVisible?: boolean }).chatOnlineVisible;

  expect(await stored()).toBe(true);

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|onboarding/);
  await page.goto("/settings");

  const toggle = page.getByRole("switch", { name: "Show when I'm online" });
  await expect(toggle).toBeChecked();

  await toggle.click();
  await expect(toggle).not.toBeChecked();
  await expect.poll(stored).toBe(false);

  await page.reload();
  await expect(page.getByRole("switch", { name: "Show when I'm online" })).not.toBeChecked();
});
