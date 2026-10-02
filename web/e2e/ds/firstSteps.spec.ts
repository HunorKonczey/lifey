import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The first-steps card (W1.11) against the gallery's section (EN): the
 *  greeting, which steps are done, a button only on pending ones, and a done
 *  step's check being announced. */

function card(page: Page, name: "goals-done" | "nothing-done" | "meal-done") {
  return page.locator(`#first-steps [data-state="${name}"]`);
}
const step = (c: ReturnType<typeof card>, id: string) => c.locator(`[data-step="${id}"]`);

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "First steps", exact: true }).scrollIntoViewIfNeeded();
});

test("greets by name and says what the tiles will do", async ({ page }) => {
  const c = card(page, "goals-done");
  await expect(c.getByRole("heading", { name: "Hi, Anna! Three steps and your day comes into view." })).toBeVisible();
  await expect(c.getByText("Tiles won't show zeros until then")).toBeVisible();
});

test("goals done (the canvas state): a check and the goal summary, no button; the other two have one each", async ({ page }) => {
  const c = card(page, "goals-done");
  await expect(step(c, "goals")).toHaveAttribute("data-done", "true");
  await expect(step(c, "goals").getByText("1,850 kcal · 110 g protein")).toBeVisible();
  await expect(step(c, "goals").getByRole("button")).toHaveCount(0);
  await expect(step(c, "goals").getByRole("img", { name: "Done" })).toBeVisible();
  await expect(step(c, "meal").getByRole("button", { name: "Log it" })).toBeVisible();
  await expect(step(c, "weight").getByRole("button", { name: "Log weight" })).toBeVisible();
});

test("nothing done: three pending steps, three buttons, goals ask to be set", async ({ page }) => {
  const c = card(page, "nothing-done");
  await expect(c.locator('[data-done="true"]')).toHaveCount(0);
  await expect(step(c, "goals").getByText("Set your daily goals")).toBeVisible();
  await expect(c.getByRole("button", { name: /Set goals|Log it|Log weight/ })).toHaveCount(3);
});

test("after the first meal the meal step ticks and loses its button; weight still waits", async ({ page }) => {
  const c = card(page, "meal-done");
  await expect(step(c, "meal")).toHaveAttribute("data-done", "true");
  await expect(step(c, "meal").getByRole("button")).toHaveCount(0);
  await expect(step(c, "weight").getByRole("button", { name: "Log weight" })).toBeVisible();
});

test("the dismiss button is labelled and only offered when the card can be dismissed", async ({ page }) => {
  await expect(card(page, "goals-done").getByRole("button", { name: "Hide this card" })).toBeVisible();
  await expect(card(page, "meal-done").getByRole("button", { name: "Hide this card" })).toHaveCount(0);
});
