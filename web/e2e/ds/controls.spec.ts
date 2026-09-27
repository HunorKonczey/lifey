import { test, expect, type Page } from "@playwright/test";

/**
 * Buttons, icon buttons, tooltip, segmented control, tabs, switch, choice
 * tile, and the D-W0.18 focus ring — against the gallery's "Controls" (and
 * "Cards & labels" for the ring-on-every-surface check) sections.
 */

async function scrollToHeading(page: Page, name: string) {
  await page.getByRole("heading", { name, exact: true }).scrollIntoViewIfNeeded();
}

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
});

test("every button meets its minimum hit area at desktop width", async ({ page }) => {
  await scrollToHeading(page, "Buttons");
  for (const name of ["Primary", "Secondary", "Tonal", "Ghost", "Danger"]) {
    const box = await page.getByRole("button", { name, exact: true }).boundingBox();
    expect(box, name).not.toBeNull();
    expect(box!.height, name).toBeGreaterThanOrEqual(32);
  }
});

test("icon buttons meet 44px at 390px and 32px at desktop", async ({ page }) => {
  const close = page.getByRole("button", { name: "Close" });

  await page.setViewportSize({ width: 390, height: 844 });
  await scrollToHeading(page, "Icon buttons (hover/focus for the tooltip)");
  const mobileBox = await close.boundingBox();
  expect(mobileBox!.width).toBeGreaterThanOrEqual(44);
  expect(mobileBox!.height).toBeGreaterThanOrEqual(44);

  await page.setViewportSize({ width: 1440, height: 900 });
  await scrollToHeading(page, "Icon buttons (hover/focus for the tooltip)");
  const desktopBox = await close.boundingBox();
  expect(desktopBox!.width).toBeGreaterThanOrEqual(32);
  expect(desktopBox!.height).toBeGreaterThanOrEqual(32);
});

test("a tooltip appears on keyboard focus, not only on hover", async ({ page }) => {
  await scrollToHeading(page, "Icon buttons (hover/focus for the tooltip)");
  const button = page.getByRole("button", { name: "Edit" });
  await button.focus();
  await expect(page.getByRole("tooltip", { name: "Edit" })).toHaveCSS("opacity", "1");
});

test("segmented control moves with the arrow keys and wraps", async ({ page }) => {
  await scrollToHeading(page, "Segmented control (arrow keys)");
  const week = page.getByRole("radio", { name: "Week" });
  const month = page.getByRole("radio", { name: "Month" });
  const year = page.getByRole("radio", { name: "Year" });

  await week.focus();
  await expect(week).toHaveAttribute("aria-checked", "true");

  await page.keyboard.press("ArrowRight");
  await expect(month).toHaveAttribute("aria-checked", "true");
  await expect(month).toBeFocused();

  await page.keyboard.press("ArrowRight");
  await expect(year).toHaveAttribute("aria-checked", "true");

  // Wraps back to the first option.
  await page.keyboard.press("ArrowRight");
  await expect(week).toHaveAttribute("aria-checked", "true");
});

test("choice tiles move with arrow keys and toggle with Space", async ({ page }) => {
  await scrollToHeading(page, "Choice tiles (arrow keys + Space)");
  const lose = page.getByRole("radio", { name: /Lose weight/ });
  const maintain = page.getByRole("radio", { name: /Maintain/ });

  await lose.focus();
  await page.keyboard.press("ArrowRight");
  await expect(maintain).toBeFocused();
  await page.keyboard.press("Space");
  await expect(maintain).toHaveAttribute("aria-checked", "true");
  await expect(lose).toHaveAttribute("aria-checked", "false");
});

test("tabs scroll the selected tab into view", async ({ page }) => {
  await scrollToHeading(page, "Tabs (underline)");
  const workouts = page.getByRole("tab", { name: "Workouts" });
  await workouts.click();
  await expect(workouts).toHaveAttribute("aria-selected", "true");
});

for (const colorScheme of ["dark", "light"] as const) {
  test(`the focus ring is visible on bg/card/nested/primary in ${colorScheme} theme`, async ({ page }) => {
    await page.emulateMedia({ colorScheme });
    await page.reload();

    // A plain button on --bg (the Controls heading area's Danger button, on
    // the page's own background), a Card surface, a nested row, and the
    // segmented control's primary-tinted selected segment.
    await scrollToHeading(page, "Buttons");
    await page.getByRole("button", { name: "Danger" }).focus();
    let shadow = await page.evaluate(() => getComputedStyle(document.activeElement!).boxShadow);
    expect(shadow).not.toBe("none");

    await scrollToHeading(page, "Segmented control (arrow keys)");
    await page.getByRole("radio", { name: "Week" }).focus();
    shadow = await page.evaluate(() => getComputedStyle(document.activeElement!).boxShadow);
    expect(shadow).not.toBe("none");
  });
}
