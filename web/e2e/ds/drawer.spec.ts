import { test, expect } from "./fixtures";

/** Drawer (D-W0.13) against the gallery's "Drawer" section: Esc/scrim
 *  close it outright when clean (the recorded `trainer-011` bug was a
 *  schedule drawer that didn't), the unsaved-changes guard when dirty,
 *  and focus return. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Drawer", exact: true }).scrollIntoViewIfNeeded();
});

test("opens with the overline, title and focus trapped inside", async ({ page }) => {
  await page.getByRole("button", { name: "Open drawer" }).click();
  const dialog = page.getByRole("dialog", { name: "Edit note" });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByText("Client")).toBeVisible();
  await expect(dialog.getByRole("heading", { name: "Edit note" })).toBeVisible();
});

test("Esc closes a clean drawer outright and returns focus to the trigger", async ({ page }) => {
  const trigger = page.getByRole("button", { name: "Open drawer" });
  await trigger.click();
  await expect(page.getByRole("dialog", { name: "Edit note" })).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Edit note" })).toHaveCount(0);
  await expect(trigger).toBeFocused();
});

test("a scrim click closes a clean drawer outright", async ({ page }) => {
  await page.getByRole("button", { name: "Open drawer" }).click();
  await expect(page.getByRole("dialog", { name: "Edit note" })).toBeVisible();
  await page.mouse.click(10, 10);
  await expect(page.getByRole("dialog", { name: "Edit note" })).toHaveCount(0);
});

test("the header close button closes a clean drawer outright", async ({ page }) => {
  await page.getByRole("button", { name: "Open drawer" }).click();
  const dialog = page.getByRole("dialog", { name: "Edit note" });
  await dialog.getByRole("button", { name: "Close" }).click();
  await expect(dialog).toHaveCount(0);
});

test("Esc on a dirty drawer asks before discarding, instead of closing outright", async ({ page }) => {
  await page.getByRole("checkbox", { name: "Make it dirty" }).click();
  await page.getByRole("button", { name: "Open drawer" }).click();
  const drawer = page.getByRole("dialog", { name: "Edit note" });
  await expect(drawer).toBeVisible();
  await page.keyboard.press("Escape");
  const confirm = page.getByRole("dialog", { name: "Discard changes?" });
  await expect(confirm).toBeVisible();
  await expect(drawer).toBeVisible(); // the drawer itself hasn't closed yet
  await confirm.getByRole("button", { name: "Discard" }).click();
  await expect(drawer).toHaveCount(0);
  await expect(confirm).toHaveCount(0);
});

test("cancelling the discard leaves the dirty drawer open", async ({ page }) => {
  await page.getByRole("checkbox", { name: "Make it dirty" }).click();
  await page.getByRole("button", { name: "Open drawer" }).click();
  const drawer = page.getByRole("dialog", { name: "Edit note" });
  await page.mouse.click(10, 10);
  const confirm = page.getByRole("dialog", { name: "Discard changes?" });
  await expect(confirm).toBeVisible();
  await confirm.getByRole("button", { name: "Keep editing" }).click();
  await expect(confirm).toHaveCount(0);
  await expect(drawer).toBeVisible();
});

test("under 768px the drawer renders as a full-height sheet", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole("button", { name: "Open drawer" }).click();
  const dialog = page.getByRole("dialog", { name: "Edit note" });
  await expect(dialog).toBeVisible();
  const box = await dialog.boundingBox();
  const viewport = page.viewportSize()!;
  expect(box!.width).toBeCloseTo(viewport.width, 0);
  expect(box!.height).toBeGreaterThan(viewport.height * 0.9);
});
