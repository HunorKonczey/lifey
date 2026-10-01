import { test, expect } from "./fixtures";

/** DS-06's shortcut layer (D-W0.17) against the gallery's standalone demo
 *  (`ShortcutsSection` mounts the same `useHotkeys` + `ShortcutHelp` pair
 *  `AppShell` does): `?` help, `G <letter>` go-to with its chord timeout,
 *  `N`/`/` page targets, and nothing firing while typing or a modal is open. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Keyboard shortcuts", exact: true }).scrollIntoViewIfNeeded();
  // Hydration finished once the section responds to a key — click empty body first
  // so focus isn't left in a field from a previous action.
  await page.locator("body").click({ position: { x: 1, y: 1 } });
});

const overlay = (page: import("@playwright/test").Page) => page.locator("#lifey-overlay-root");

test("? opens the help overlay listing page and global shortcuts, Escape closes it", async ({ page }) => {
  await page.keyboard.press("?");
  const dialog = overlay(page).getByRole("dialog", { name: "Keyboard shortcuts" });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByText("Add a demo entry")).toBeVisible();
  await expect(dialog.getByText("Shift+F10")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(dialog).toHaveCount(0);
});

test("G then a letter navigates to the matching item", async ({ page }) => {
  await page.keyboard.press("g");
  await page.keyboard.press("w");
  await expect(page).toHaveURL(/#go-workouts$/);
});

test("the G chord times out after a second", async ({ page }) => {
  await page.keyboard.press("g");
  await page.waitForTimeout(1200);
  await page.keyboard.press("d");
  await expect(page).not.toHaveURL(/#go-dashboard/);
});

test("N runs the page's new-entry action", async ({ page }) => {
  await page.keyboard.press("n");
  await expect(page.getByTestId("new-count")).toHaveText("Entries added: 1");
});

test("/ focuses the page's search field", async ({ page }) => {
  await page.keyboard.press("/");
  await expect(page.getByRole("textbox", { name: "Demo search" })).toBeFocused();
});

test("shortcuts are ignored while typing in a field", async ({ page }) => {
  const search = page.getByRole("textbox", { name: "Demo search" });
  await search.focus();
  await page.keyboard.type("n?g");
  await expect(search).toHaveValue("n?g");
  await expect(page.getByTestId("new-count")).toHaveText("Entries added: 0");
  await expect(overlay(page).getByRole("dialog")).toHaveCount(0);
});

test("shortcuts are ignored while a modal owns focus", async ({ page }) => {
  await page.keyboard.press("?");
  await expect(overlay(page).getByRole("dialog", { name: "Keyboard shortcuts" })).toBeVisible();
  await page.keyboard.press("n");
  await expect(page.getByTestId("new-count")).toHaveText("Entries added: 0");
});
