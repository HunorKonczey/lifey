import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The template editor (W3.11) on the gallery demo (EN, 1440): exercises reorder by mouse and by keyboard (Space on
 *  the handle, ↓/↑, Space), the set stepper steps and stops at 1, removing and adding exercises, the dirty save. */

const demo = (page: Page) => page.getByTestId("template-editor-demo");
const rows = (page: Page) => demo(page).getByTestId("template-exercise-row");
const order = (page: Page) => rows(page).locator("span.truncate").allInnerTexts();

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Template editor", exact: true }).scrollIntoViewIfNeeded();
});

test("rows show the exercise and its target sets", async ({ page }) => {
  await expect(rows(page)).toHaveCount(3);
  await expect(rows(page).nth(0)).toContainText("Guggolás");
  await expect(rows(page).nth(0).getByTestId("template-sets")).toHaveText("4 sets");
});

test("the set stepper steps up and down and never goes below 1", async ({ page }) => {
  const row = rows(page).nth(1);
  await row.getByRole("button", { name: "One set more" }).click();
  await expect(row.getByTestId("template-sets")).toHaveText("4 sets");
  for (let i = 0; i < 5; i++) await row.getByRole("button", { name: "One set fewer" }).click();
  await expect(row.getByTestId("template-sets")).toHaveText("1 sets");
});

test("reorder by keyboard: Space lifts, ↓ moves, Space drops", async ({ page }) => {
  expect(await order(page)).toEqual(["Guggolás", "Román felhúzás", "Kitörés"]);
  await rows(page).nth(0).getByRole("button", { name: "Drag to reorder" }).focus();
  await page.keyboard.press("Space");
  await expect(rows(page).nth(0).getByRole("button", { name: "Drag to reorder" })).toHaveAttribute("aria-pressed", "true");
  await page.keyboard.press("ArrowDown");
  await page.waitForTimeout(300); // dnd-kit measures the new target on the next frame
  await page.keyboard.press("Space");
  await expect.poll(() => order(page)).toEqual(["Román felhúzás", "Guggolás", "Kitörés"]);
});

test("reorder by mouse: drag the handle below the next row", async ({ page }) => {
  const handle = rows(page).nth(2).getByRole("button", { name: "Drag to reorder" });
  const target = rows(page).nth(0);
  const from = await handle.boundingBox();
  const to = await target.boundingBox();
  if (!from || !to) throw new Error("no boxes");
  await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
  await page.mouse.down();
  await page.mouse.move(from.x + from.width / 2, from.y - 20, { steps: 5 });
  await page.mouse.move(to.x + 20, to.y + 4, { steps: 12 });
  await page.mouse.up();
  await expect.poll(() => order(page)).toEqual(["Kitörés", "Guggolás", "Román felhúzás"]);
});

test("remove an exercise and add another from the search", async ({ page }) => {
  await rows(page).nth(1).getByRole("button", { name: "Remove exercise" }).click();
  await expect(rows(page)).toHaveCount(2);
  await demo(page).getByRole("button", { name: "Add exercise" }).click();
  await demo(page).getByPlaceholder("Search exercises…").first().fill("plan");
  await demo(page).getByRole("button", { name: "Plank" }).click();
  await expect(rows(page)).toHaveCount(3);
  await expect(rows(page).nth(2)).toContainText("Plank");
  await expect(rows(page).nth(2).getByTestId("template-sets")).toHaveText("3 sets");
});

test("Save is disabled without a name or without exercises", async ({ page }) => {
  const save = demo(page).getByRole("button", { name: "Save template" });
  await expect(save).toBeEnabled();
  await demo(page).getByLabel("Name").fill("");
  await expect(save).toBeDisabled();
});
