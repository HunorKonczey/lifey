import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The live logger's set rows (W3.7) on the gallery demo (EN, 1440): the keyboard path — Tab to the fields,
 *  type, Enter ticks the row and moves to the next one, Enter on the last row adds a set, ↑/↓ step the weight
 *  2.5 kg — plus the 🏆 / ↑ marks, the done tint and the 18 px fields. */

const demo = (page: Page) => page.getByTestId("set-rows-demo");
const row = (page: Page, n: number) => demo(page).locator(`[data-set-row="${n}"]`);
const kg = (page: Page, n: number) => row(page, n).getByRole("textbox", { name: `kg ${n + 1}` });
const reps = (page: Page, n: number) => row(page, n).getByRole("textbox", { name: `Reps ${n + 1}` });
const state = (page: Page) => page.getByTestId("set-rows-state");

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Live logger set rows", exact: true }).scrollIntoViewIfNeeded();
});

test("kg and reps are 18 px / 800 fields and the row shows the previous session", async ({ page }) => {
  const size = await kg(page, 1).evaluate((el) => {
    const s = getComputedStyle(el);
    return { fontSize: s.fontSize, fontWeight: s.fontWeight };
  });
  expect(size).toEqual({ fontSize: "18px", fontWeight: "800" });
  await expect(row(page, 1)).toContainText("57.5 kg × 8");
  await expect(demo(page)).toContainText("best so far 60 kg × 6");
});

test("Enter in a row ticks it and focuses the next row's kg field", async ({ page }) => {
  await kg(page, 1).focus();
  await page.keyboard.press("Enter");
  await expect(row(page, 1)).toHaveAttribute("data-done", "true");
  await expect(kg(page, 2)).toBeFocused();
  await expect(state(page)).toHaveText("55×8✓ 57.5×8✓ 57.5×8");
});

test("Enter on the last row adds a set and focuses it", async ({ page }) => {
  await kg(page, 2).focus();
  await page.keyboard.press("Enter");
  await expect(row(page, 3)).toBeVisible();
  await expect(kg(page, 3)).toBeFocused();
  await expect(state(page)).toHaveText("55×8✓ 57.5×8 57.5×8✓ 57.5×8");
});

test("a typed value is kept: Tab, type, Enter", async ({ page }) => {
  await kg(page, 1).focus();
  await page.keyboard.type("60");
  await reps(page, 1).focus();
  await page.keyboard.type("9");
  await page.keyboard.press("Enter");
  await expect(state(page)).toContainText("60×9✓");
});

test("↑ and ↓ step the weight by 2.5 kg and the reps by 1", async ({ page }) => {
  await kg(page, 1).focus();
  await page.keyboard.press("ArrowUp");
  await expect(kg(page, 1)).toHaveValue("60");
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("ArrowDown");
  await expect(kg(page, 1)).toHaveValue("55");
  await reps(page, 1).focus();
  await page.keyboard.press("ArrowUp");
  await expect(reps(page, 1)).toHaveValue("9");
});

test("🏆 shows the moment a record set is ticked, ↑ when it only beats last time", async ({ page }) => {
  await expect(row(page, 1).getByRole("img", { name: "Personal record" })).toHaveCount(0);
  // 62.5 × 8 is heavier than anything in the history (60)
  await kg(page, 1).focus();
  await page.keyboard.type("62.5");
  await page.keyboard.press("Enter");
  await expect(row(page, 1).getByRole("img", { name: "Personal record" })).toBeVisible();
  // 58 × 8 at row 3 is heavier than last time's 57.5 × 8 but breaks no record (62.5 × 8 above already is the best)
  await kg(page, 2).focus();
  await page.keyboard.type("58");
  await page.keyboard.press("Enter");
  await expect(row(page, 2).getByRole("img", { name: "Better than last time" })).toBeVisible();
  await expect(row(page, 2).getByRole("img", { name: "Personal record" })).toHaveCount(0);
});

test("a done row takes the protein tint", async ({ page }) => {
  const bg = (n: number) => row(page, n).evaluate((el) => getComputedStyle(el).backgroundColor);
  const before = await bg(1);
  await kg(page, 1).focus();
  await page.keyboard.press("Enter");
  await expect.poll(() => bg(1)).not.toBe(before);
});
