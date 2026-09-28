import { test, expect } from "@playwright/test";

/** DS-02's superadmin sidebar (D-W0.24) against the "Sidebar & account
 *  menu" gallery demo's Superadmin toggle: flat nav (no groups), the
 *  neutral RENDSZER badge, and no Settings row (reached via the account
 *  menu, same as the trainer shell). */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Sidebar & account menu", exact: true }).scrollIntoViewIfNeeded();
  await page.locator("#shell").getByRole("button", { name: "Superadmin", exact: true }).click();
});

test("shows the flat nav and the SYSTEM badge, no group headers", async ({ page }) => {
  const section = page.locator("#shell");
  await expect(section.getByText("Users", { exact: true })).toBeVisible();
  await expect(section.getByText("Trainer requests", { exact: true })).toBeVisible();
  await expect(section.getByText("Back to my view", { exact: true })).toBeVisible();
  await expect(section.getByText("SYSTEM", { exact: true })).toBeVisible();
});

test("has no dedicated Settings row — it's reached through the account menu", async ({ page }) => {
  const section = page.locator("#shell");
  await expect(section.getByRole("link", { name: "Settings" })).toHaveCount(0);
});
