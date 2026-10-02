import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The edit-meal drawer (W2.7) against the gallery's section: Save disabled
 *  until something changed, the unsaved chip, the discard guard on Esc / scrim
 *  / ×, one-decimal quantities that round-trip, kcal following the quantity,
 *  and the Hungarian copy. */

const drawer = (page: Page, name = "Edit Breakfast") => page.locator("#lifey-overlay-root").getByRole("dialog", { name });
const yoghurt = (page: Page) => drawer(page).getByRole("textbox", { name: "Görög joghurt 2%" });

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Edit meal drawer", exact: true }).scrollIntoViewIfNeeded();
  await page.getByTestId("open-edit-meal").click();
  await expect(drawer(page)).toBeVisible();
});

test("opens clean: one row per food, Save disabled, no unsaved chip", async ({ page }) => {
  await expect(drawer(page).getByTestId("edit-meal-rows").getByRole("listitem")).toHaveCount(3);
  await expect(drawer(page).getByRole("button", { name: "Save" })).toBeDisabled();
  await expect(drawer(page).getByText("Unsaved change")).toHaveCount(0);
});

test("a stored 166.68518 g is shown as 166.7 — one decimal", async ({ page }) => {
  await expect(yoghurt(page)).toHaveValue("166.7");
});

test("changing a quantity enables Save, shows the chip and updates that row's kcal", async ({ page }) => {
  const row = drawer(page).getByRole("listitem").filter({ has: page.getByRole("textbox", { name: "Görög joghurt 2%" }) });
  await expect(row.getByText("122", { exact: true })).toBeVisible();
  await yoghurt(page).fill("100");
  await expect(drawer(page).getByText("Unsaved change")).toBeVisible();
  await expect(drawer(page).getByRole("button", { name: "Save" })).toBeEnabled();
  await expect(row.getByText("73", { exact: true })).toBeVisible(); // 122 × 100 / 166.685
});

test("typing back the number the drawer showed is not a change", async ({ page }) => {
  await yoghurt(page).fill("166.7");
  await yoghurt(page).blur();
  await expect(drawer(page).getByRole("button", { name: "Save" })).toBeDisabled();
  await expect(drawer(page).getByText("Unsaved change")).toHaveCount(0);
});

test("save sends the edited row and the untouched rows exactly as stored", async ({ page }) => {
  await drawer(page).getByRole("textbox", { name: "Áfonya" }).fill("90");
  await drawer(page).getByRole("button", { name: "Save" }).click();
  await expect(drawer(page)).toHaveCount(0);
  await expect(page.getByTestId("saved-log")).toHaveText("Saved: 1:60, 2:166.68518, 3:90");
});

test("Esc on a dirty drawer asks first; Keep editing returns, Discard closes without saving", async ({ page }) => {
  await yoghurt(page).fill("120");
  await page.keyboard.press("Escape");
  const confirm = page.getByRole("dialog", { name: "Discard changes?" });
  await expect(confirm).toBeVisible();
  await confirm.getByRole("button", { name: "Keep editing" }).click();
  await expect(drawer(page)).toBeVisible();
  await page.keyboard.press("Escape");
  await confirm.getByRole("button", { name: "Discard" }).click();
  await expect(drawer(page)).toHaveCount(0);
  await expect(page.getByTestId("saved-log")).toHaveText("Saved: —");
});

test("Esc on a clean drawer just closes it", async ({ page }) => {
  await page.keyboard.press("Escape");
  await expect(drawer(page)).toHaveCount(0);
});

test("the footer's secondary button discards (closes) without saving", async ({ page }) => {
  await drawer(page).getByRole("button", { name: "Discard" }).click();
  await expect(drawer(page)).toHaveCount(0);
  await expect(page.getByTestId("saved-log")).toHaveText("Saved: —");
});

test("in Hungarian: the decimal comma, 'Nem mentett változás', Elvetés / Mentés", async ({ page }) => {
  await page.keyboard.press("Escape");
  await page.getByRole("button", { name: "HU", exact: true }).click();
  await page.getByTestId("open-edit-meal").click();
  const hu = drawer(page, "Reggeli szerkesztése");
  await expect(hu).toBeVisible();
  await expect(hu.getByRole("textbox", { name: "Görög joghurt 2%" })).toHaveValue("166,7");
  await hu.getByRole("textbox", { name: "Áfonya" }).fill("85,5");
  await expect(hu.getByText("Nem mentett változás")).toBeVisible();
  await expect(hu.getByRole("button", { name: "Mentés" })).toBeEnabled();
  await expect(hu.getByRole("button", { name: "Elvetés" })).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Elveted a módosításokat?" })).toBeVisible();
});
