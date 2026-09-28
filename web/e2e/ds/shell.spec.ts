import { test, expect, type Page } from "@playwright/test";

/** DS-02's client sidebar + account menu (D-W0.20) against the gallery's
 *  "Sidebar & account menu" section: collapse, persistence, the collapsed
 *  tooltip, the account menu, and the logout dialog's default focus. */

// Scoped to the section — the mobile bottom-nav demo elsewhere on this same
// page also has a "Dashboard" link, sharing the same aria-label.
function section(page: Page) {
  return page.locator("#shell");
}

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Sidebar & account menu", exact: true }).scrollIntoViewIfNeeded();
});

test("collapsing the sidebar hides labels and shows the expand toggle", async ({ page }) => {
  await expect(section(page).getByText("Dashboard", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Collapse sidebar" }).click();
  // The link itself stays reachable and named via aria-label (D-W0.17) — only
  // its visible text span goes away.
  await expect(section(page).getByText("Dashboard", { exact: true })).toHaveCount(0);
  await expect(section(page).getByRole("link", { name: "Dashboard" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Expand sidebar" })).toBeVisible();
});

test("the collapsed state persists across a reload", async ({ page }) => {
  await page.getByRole("button", { name: "Collapse sidebar" }).click();
  await page.reload();
  await page.getByRole("heading", { name: "Sidebar & account menu", exact: true }).scrollIntoViewIfNeeded();
  await expect(page.getByRole("button", { name: "Expand sidebar" })).toBeVisible();
  // Leave it open again for the tests that follow in this file.
  await page.getByRole("button", { name: "Expand sidebar" }).click();
});

test("a collapsed item's tooltip shows its label and go-to shortcut", async ({ page }) => {
  await page.getByRole("button", { name: "Collapse sidebar" }).click();
  const dashboard = section(page).getByRole("link", { name: "Dashboard" });
  await dashboard.focus();
  const tooltip = page.getByRole("tooltip", { name: "Dashboard" });
  await expect(tooltip).toHaveCSS("opacity", "1");
  await expect(tooltip).toContainText("G D");
});

test("the account menu opens from the user chip and offers sign out", async ({ page }) => {
  await page.getByRole("button", { name: /Nagy Kata/ }).click();
  // Portals into the shared overlay root, distinct from the sidebar's own
  // always-visible "Settings" row underneath it.
  const menu = page.locator("#lifey-overlay-root");
  await expect(menu.getByRole("link", { name: "Settings" })).toBeVisible();
  await expect(menu.getByRole("button", { name: "Sign out…" })).toBeVisible();
});

test("the logout dialog defaults focus to Cancel, never the destructive action", async ({ page }) => {
  await page.getByRole("button", { name: /Nagy Kata/ }).click();
  await page.getByRole("button", { name: "Sign out…" }).click();
  const dialog = page.getByRole("dialog", { name: "Sign out?" });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Cancel" })).toBeFocused();
});
