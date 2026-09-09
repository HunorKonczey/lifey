import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { routing } from "../../src/i18n/routing";

/**
 * WCAG 2.1 AA over the whole marketing tree, in **both** colour schemes
 * (docs/landing_page/72 Prompt 4).
 *
 * Why both schemes: every accessibility defect this suite was written for was
 * light-theme-only — two `color-contrast` failures on the app page that a
 * dark-only run passes straight over (72 W3). It is the same trap commit
 * 1c252fd documented for Lighthouse, where CI and local runs silently audited
 * different themes.
 *
 * The theme is decided before first paint by the inline script in
 * `app/layout.tsx`, which reads `prefers-color-scheme` — so switching schemes
 * needs a **reload**, not just `emulateMedia` on an already-rendered page.
 *
 * The route list comes from `routing.pathnames` itself rather than a hand-kept
 * copy: a new marketing page has to be registered there before it can be
 * linked anywhere, so deriving from it means a new page is audited the day it
 * exists. The two 404 shapes are appended by hand, since by definition they
 * are not in the route table.
 */

const localizedPaths = routing.locales.flatMap((locale) =>
  Object.values(routing.pathnames).map((pathname) => {
    const path = typeof pathname === "string" ? pathname : pathname[locale];
    return `/${locale}${path === "/" ? "" : path}`;
  })
);

const notFoundPaths = [
  "/hu/nincs-ilyen-oldal", // catch-all under a known locale → marketing 404
  "/de/whatever", // unknown locale → root 404
];

const paths = [...localizedPaths, ...notFoundPaths];

for (const path of paths) {
  test(`${path} has no WCAG 2.1 AA violations in either theme`, async ({ page }) => {
    for (const colorScheme of ["dark", "light"] as const) {
      await page.emulateMedia({ colorScheme });
      await page.goto(path);
      await page.waitForLoadState("networkidle");

      const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
        .analyze();

      expect(
        results.violations.map((v) => `${v.id} (${v.nodes.length}): ${v.nodes[0]?.html.slice(0, 120)}`),
        `${path} — ${colorScheme} theme`
      ).toEqual([]);
    }
  });
}
