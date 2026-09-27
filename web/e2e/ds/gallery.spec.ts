import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { GALLERY_SECTIONS } from "../../src/components/ds/gallery/registry";

/**
 * The dev design gallery (`/dev/design`, D-W0.12) — no backend needed, so
 * this runs in CI next to `marketing`. Every later W0 step's gallery section
 * gets exercised here as it lands; for now this covers what W0.5 itself
 * ships: the page renders, both themes are clean under axe, and 390px has
 * no horizontal scroll.
 */

for (const colorScheme of ["dark", "light"] as const) {
  test(`/dev/design has no WCAG 2.1 AA violations in ${colorScheme} theme`, async ({ page }) => {
    await page.emulateMedia({ colorScheme });
    await page.goto("/dev/design");
    await page.waitForLoadState("networkidle");

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
      .analyze();

    expect(
      results.violations.map((v) => `${v.id} (${v.nodes.length}): ${v.nodes[0]?.html.slice(0, 120)}`)
    ).toEqual([]);
  });
}

test("renders every registered section", async ({ page }) => {
  await page.goto("/dev/design");
  for (const { title } of GALLERY_SECTIONS) {
    await expect(page.getByRole("heading", { name: title, exact: true })).toBeVisible();
  }
});

test("no horizontal scroll at 390px", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/design");
  await page.getByRole("button", { name: "390", exact: true }).click();

  const { scrollWidth, clientWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(scrollWidth).toBeLessThanOrEqual(clientWidth);
});

test("the reduced-motion toggle sets the forced attribute", async ({ page }) => {
  await page.goto("/dev/design");
  const toggle = page.getByLabel("Reduced motion");
  await toggle.check();
  await expect(page.locator("html")).toHaveAttribute("data-force-reduced-motion", "true");
  await toggle.uncheck();
  await expect(page.locator("html")).toHaveAttribute("data-force-reduced-motion", "false");
});
