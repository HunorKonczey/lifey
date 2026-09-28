import { test, expect, type Page } from "@playwright/test";

/** DS-02's mobile shell below 768px (D-W0.22) against the gallery's
 *  standalone demo, both role configs, at 390x844: hit areas, no
 *  horizontal scroll, and the "Több" sheet being keyboard-operable. */

// Scoped to the section — the desktop `Sidebar` demo elsewhere on this same
// page shares the exact "Main navigation" aria-label, and `BottomNav` is
// `position: fixed` (not a portal), so it stays inside this DOM subtree.
function section(page: Page) {
  return page.locator("#mobile-shell");
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Mobile shell (bottom nav)", exact: true }).scrollIntoViewIfNeeded();
});

for (const role of ["Client", "Trainer"] as const) {
  test(`${role}: every bottom nav item meets 44px and there's no horizontal scroll`, async ({ page }) => {
    if (role === "Trainer") await section(page).getByRole("button", { name: "Trainer", exact: true }).click();

    const nav = section(page).getByRole("navigation", { name: "Main navigation" });
    const links = await nav.getByRole("link").all();
    expect(links.length).toBeGreaterThan(0);
    for (const link of links) {
      const box = await link.boundingBox();
      expect(box!.width).toBeGreaterThanOrEqual(44);
      expect(box!.height).toBeGreaterThanOrEqual(44);
    }

    const hasHorizontalScroll = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
    expect(hasHorizontalScroll).toBe(false);
  });
}

test("the active item shows as a filled pill with its label, others stay icon-only", async ({ page }) => {
  const nav = section(page).getByRole("navigation", { name: "Main navigation" });
  await expect(nav.getByText("Dashboard")).toBeVisible();
  await expect(nav.getByText("Nutrition")).toHaveCount(0);
});

test("Több opens a keyboard-operable sheet and Esc closes it, returning focus", async ({ page }) => {
  const trigger = section(page).getByRole("button", { name: "More" });
  // Focus + Enter rather than a mouse click — the dev-only TanStack Query
  // devtools toggle sits in the same bottom-right corner at this width and
  // would otherwise intercept the pointer event (a `next dev`-only overlay,
  // absent from production, but present in the CI `ds` webServer too).
  await trigger.focus();
  await page.keyboard.press("Enter");
  const sheet = page.getByRole("dialog", { name: "More" });
  await expect(sheet).toBeVisible();

  const items = sheet.getByRole("link");
  const count = await items.count();
  await expect(items.nth(count - 1)).toBeVisible();

  await page.keyboard.press("Escape");
  await expect(sheet).toHaveCount(0);
  await expect(trigger).toBeFocused();
});
