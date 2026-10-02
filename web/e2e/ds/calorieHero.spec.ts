import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The dashboard hero's three states (W1.2) against the gallery's "Calorie
 *  hero" section (EN): the number/caption choice, the goal line, and a macro
 *  without a goal showing its value only. */

function state(page: Page, name: "remaining" | "over" | "no-goal") {
  return page.locator(`#calorie-hero [data-state="${name}"]`);
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Calorie hero", exact: true }).scrollIntoViewIfNeeded();
});

test("under budget: 859 kcal left, eaten and daily goal beside it, macros with grams left", async ({ page }) => {
  const hero = state(page, "remaining");
  await expect(hero.getByTestId("hero-number")).toHaveText("859");
  await expect(hero.getByTestId("hero-caption")).toHaveText("kcal left");
  await expect(hero.getByText("Daily goal", { exact: true })).toBeVisible();
  await expect(hero.getByTestId("macro-protein")).toContainText("68 / 120 g · 52 g left");
  await expect(hero.getByRole("button", { name: "Add meal" })).toBeVisible();
});

test("over budget: the number is the overage and the caption says over", async ({ page }) => {
  const hero = state(page, "over");
  await expect(hero.getByTestId("hero-number")).toHaveText("212");
  await expect(hero.getByTestId("hero-caption")).toHaveText("kcal over");
  // The overage caption is painted in the kcal colour, unlike the neutral "left" caption.
  const color = (name: "remaining" | "over") =>
    state(page, name).getByTestId("hero-caption").evaluate((el) => getComputedStyle(el).color);
  expect(await color("over")).not.toBe(await color("remaining"));
  await expect(hero.getByTestId("macro-protein")).toContainText("15 g over");
});

test("no calorie goal: the number is what was eaten, no daily-goal line, macros show values only", async ({ page }) => {
  const hero = state(page, "no-goal");
  await expect(hero.getByTestId("hero-number")).toHaveText("640");
  await expect(hero.getByTestId("hero-caption")).toHaveText("kcal eaten");
  await expect(hero.getByText("Daily goal", { exact: true })).toHaveCount(0);
  await expect(hero.getByTestId("macro-protein")).toHaveText(/Protein\s*41 g$/);
  await expect(hero.getByRole("link", { name: "Set your daily goals to track progress" })).toBeVisible();
});

test("the hero card is not itself a button or link", async ({ page }) => {
  const card = state(page, "remaining").getByTestId("calorie-hero");
  await expect(card).not.toHaveAttribute("role", "button");
  await expect(card).not.toHaveAttribute("tabindex", "0");
});

test("at 390 the add button shows the short label and nothing scrolls sideways", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload();
  const hero = state(page, "remaining");
  await expect(hero.getByRole("button", { name: "Meal" })).toBeVisible();
  // compact hero (W1-C): eaten / goal moves inside the ring, the side column goes
  await expect(hero.getByTestId("hero-ring-sub")).toHaveText("1,041 / 1,900");
  await expect(hero.getByText("Eaten", { exact: true })).toBeHidden();
  expect(await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth)).toBe(false);
});
