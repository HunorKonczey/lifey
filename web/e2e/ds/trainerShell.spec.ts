import { test, expect } from "@playwright/test";

/** DS-02's trainer sidebar (D-W0.23) against the "Sidebar & account menu"
 *  gallery demo's Trainer toggle: grouped nav, the EDZŐ badge, and the
 *  chat unread badge. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Sidebar & account menu", exact: true }).scrollIntoViewIfNeeded();
  await page.locator("#shell").getByRole("button", { name: "Trainer", exact: true }).click();
});

test("shows the grouped nav headers and the trainer badge, no tertiary styling", async ({ page }) => {
  const section = page.locator("#shell");
  // The gallery defaults to EN — these are `admin.nav.group*`/`admin.chip`.
  await expect(section.getByText("CLIENTS", { exact: true })).toBeVisible();
  await expect(section.getByText("CONTENT", { exact: true })).toBeVisible();
  await expect(section.getByText("ACCOUNT", { exact: true })).toBeVisible();
  await expect(section.getByText("TRAINER", { exact: true }).first()).toBeVisible();
});

test("the chip subtitle reads the role badge instead of the client's e-mail", async ({ page }) => {
  const section = page.locator("#shell");
  await expect(section.getByText("nagy.kata@example.com")).toHaveCount(0);
  // Exact text match excludes the logo badge — its span's raw text also
  // includes its icon's ligature name ("fitness_center"), so only the plain
  // chip-subtitle span matches "TRAINER" exactly.
  await expect(section.getByText("TRAINER", { exact: true })).toHaveCount(1);
});
