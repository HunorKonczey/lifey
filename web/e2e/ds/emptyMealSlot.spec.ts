import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The empty meal-type slot (W2.4) against the gallery's section (EN). */

function slot(page: Page, name: "with-copy" | "budget-only" | "no-budget" | "used-up") {
  return page.locator(`#empty-slot [data-state="${name}"]`);
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Empty meal slot", exact: true }).scrollIntoViewIfNeeded();
});

test("dinner: 'nothing logged yet · 859 kcal fits', a yesterday chip with its kcal, and Add", async ({ page }) => {
  const s = slot(page, "with-copy");
  await expect(s.getByRole("heading", { name: "Dinner" })).toBeVisible();
  await expect(s.getByText("Nothing logged yet · 859 kcal fits")).toBeVisible();
  await expect(s.getByRole("button", { name: "Yesterday's dinner · 612 kcal" })).toBeVisible();
  await expect(s.getByRole("button", { name: "Add" })).toBeVisible();
});

test("without a copy offer there is no chip", async ({ page }) => {
  const s = slot(page, "budget-only");
  await expect(s.getByText("859 kcal fits")).toBeVisible();
  await expect(s.getByRole("button", { name: /Yesterday/ })).toHaveCount(0);
});

test("no goal, or nothing left in the budget: just 'Nothing logged yet'", async ({ page }) => {
  await expect(slot(page, "no-budget").getByText("Nothing logged yet", { exact: true })).toBeVisible();
  await expect(slot(page, "used-up").getByText("Nothing logged yet", { exact: true })).toBeVisible();
  await expect(slot(page, "used-up").getByText(/fits/)).toHaveCount(0);
});

test("the slot is a quiet nested card, not a dashed outline", async ({ page }) => {
  const card = slot(page, "with-copy").getByTestId("empty-slot");
  const style = await card.evaluate((el) => getComputedStyle(el));
  expect(style.borderTopStyle).not.toBe("dashed");
});
