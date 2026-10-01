import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The copy-from-day popover (W2.9) against the gallery's section (viewing Sep 27, 2026; the 26th has
 *  three meals, the 25th one, the 20th two): day chips, the day's meals with checkboxes and kcal,
 *  "Copy N meals", the never-overwrites note, the calendar for "Another day", keyboard and Hungarian. */

const popover = (page: Page) => page.getByTestId("copy-from-day");
const copyButton = (page: Page, name: RegExp) => popover(page).getByRole("button", { name });
const mealBox = (page: Page, name: RegExp) => popover(page).getByRole("checkbox", { name });

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Copy from day popover", exact: true }).scrollIntoViewIfNeeded();
  await page.getByTestId("open-copy-from-day").click();
  await expect(popover(page)).toBeVisible();
});

test("opens on yesterday with its meals all ticked, their kcal and the never-overwrites note", async ({ page }) => {
  await expect(popover(page).getByRole("button", { name: "Yesterday · Sep 26" })).toHaveAttribute("aria-pressed", "true");
  const rows = popover(page).getByTestId("copy-day-meals").getByRole("listitem");
  await expect(rows).toHaveCount(3);
  await expect(rows.nth(0)).toContainText("Breakfast");
  await expect(rows.nth(0)).toContainText("379 kcal");
  await expect(rows.nth(1)).toContainText("Csirkés rizstál brokkolival"); // a recipe shows its name
  await expect(popover(page).getByRole("checkbox", { checked: true })).toHaveCount(3);
  await expect(copyButton(page, /Copy 3 meals/)).toBeEnabled();
  await expect(popover(page).getByText("Added to today, nothing is overwritten.")).toBeVisible();
});

test("the first control focused is the first day chip", async ({ page }) => {
  await expect(popover(page).getByRole("button", { name: "Yesterday · Sep 26" })).toBeFocused();
});

test("unticking meals changes the count; none ticked disables the button", async ({ page }) => {
  await mealBox(page, /Lunch/).click();
  await expect(copyButton(page, /Copy 2 meals/)).toBeVisible();
  await mealBox(page, /Breakfast/).click();
  await expect(copyButton(page, /Copy 1 meal$/)).toBeVisible();
  await mealBox(page, /Dinner/).click();
  await expect(copyButton(page, /Copy 0 meals/)).toBeDisabled();
});

test("copy hands over exactly the ticked meals, in the order they happened, and closes", async ({ page }) => {
  await mealBox(page, /Lunch/).click();
  await copyButton(page, /Copy 2 meals/).click();
  await expect(page.getByTestId("copy-log")).toHaveText("Copied: 1, 3");
  await expect(popover(page)).toHaveCount(0);
});

test("the second chip shows the day before, its single meal", async ({ page }) => {
  await popover(page).getByRole("button", { name: "Sep 25" }).click();
  await expect(popover(page).getByTestId("copy-day-meals").getByRole("listitem")).toHaveCount(1);
  await expect(copyButton(page, /Copy 1 meal$/)).toBeVisible();
});

test("Another day opens the month grid with dots on logged days; picking one loads its meals", async ({ page }) => {
  await popover(page).getByRole("button", { name: "Another day" }).click();
  const grid = popover(page).getByRole("grid");
  await expect(grid).toBeVisible();
  await expect(grid.getByRole("gridcell", { name: /Sep 20, 2026/ }).locator("span")).toHaveCount(1);
  await expect(grid.getByRole("gridcell", { name: /Sep 21, 2026/ }).locator("span")).toHaveCount(0);
  await grid.getByRole("gridcell", { name: /Sep 20, 2026/ }).click();
  await expect(popover(page).getByRole("button", { name: "Another day · Sep 20" })).toHaveAttribute("aria-pressed", "true");
  await expect(popover(page).getByTestId("copy-day-meals").getByRole("listitem")).toHaveCount(2);
  await expect(copyButton(page, /Copy 2 meals/)).toBeEnabled();
});

test("a day with nothing logged says so and cannot be copied", async ({ page }) => {
  await popover(page).getByRole("button", { name: "Another day" }).click();
  await popover(page).getByRole("grid").getByRole("gridcell", { name: /Sep 10, 2026/ }).click();
  await expect(popover(page).getByText("Nothing was logged on this day.")).toBeVisible();
  await expect(copyButton(page, /Copy 0 meals/)).toBeDisabled();
});

test("Esc closes it and focus returns to the trigger", async ({ page }) => {
  await page.keyboard.press("Escape");
  await expect(popover(page)).toHaveCount(0);
  await expect(page.getByTestId("open-copy-from-day")).toBeFocused();
});

test("reopening starts over on yesterday with everything ticked", async ({ page }) => {
  await mealBox(page, /Lunch/).click();
  await popover(page).getByRole("button", { name: "Sep 25" }).click();
  await page.keyboard.press("Escape");
  await page.getByTestId("open-copy-from-day").click();
  await expect(popover(page).getByRole("button", { name: "Yesterday · Sep 26" })).toHaveAttribute("aria-pressed", "true");
  await expect(popover(page).getByRole("checkbox", { checked: true })).toHaveCount(3);
});

test("in Hungarian: Tegnap chip, tétel, the note and 'N étkezés másolása'", async ({ page }) => {
  await page.keyboard.press("Escape");
  await page.getByRole("button", { name: "HU", exact: true }).click();
  await page.getByTestId("open-copy-from-day").click();
  await expect(popover(page).getByRole("button", { name: /^Tegnap · szept\. 26\.$/ })).toBeVisible();
  await expect(popover(page).getByText("3 tétel").first()).toBeVisible();
  await expect(popover(page).getByText("A mai naphoz adódik, nem írja felül.")).toBeVisible();
  await expect(copyButton(page, /3 étkezés másolása/)).toBeVisible();
  await expect(popover(page).getByRole("button", { name: "Másik nap" })).toBeVisible();
});
