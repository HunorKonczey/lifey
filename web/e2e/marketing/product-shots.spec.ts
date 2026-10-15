import { test, expect } from "@playwright/test";

/**
 * The captures of the real product in the value blocks (LIF-120, docs/landing_page/72 W12): the home page and the for-trainers
 * page each show the clients, programme and chat pages of the demo dataset. One file per language and per theme exists; the
 * page must show the one that matches both and must not fetch the other theme's (a lazy image that is not displayed is not
 * loaded). Without a backend: the files are static.
 */

const ALT = {
  hu: [/Egy kliens áttekintése/, /Hat hetes erőprogram/, /Edző és kliens beszélgetése/],
  en: [
    /A client's overview/,
    /A six-week strength programme/,
    /A conversation between a trainer and a client/,
  ],
} as const;

const PAGES = [
  ["/hu", "hu"],
  ["/en", "en"],
  ["/hu/edzoknek", "hu"],
  ["/en/for-trainers", "en"],
] as const;

for (const [path, locale] of PAGES) {
  for (const theme of ["dark", "light"] as const) {
    test(`${path} in the ${theme} theme shows the ${locale} ${theme} captures and fetches no others`, async ({
      page,
    }) => {
      await page.addInitScript((t) => {
        try {
          localStorage.setItem("lifey-theme", t);
        } catch {
          /* storage off */
        }
      }, theme);
      const fetched: string[] = [];
      page.on("request", (request) => {
        const url = decodeURIComponent(request.url());
        if (url.includes("/marketing/shots/")) fetched.push(url);
      });

      await page.goto(path);
      // Scroll the whole page, so every lazy image gets its chance to load.
      await page.evaluate(async () => {
        for (let y = 0; y < document.body.scrollHeight; y += 500) {
          window.scrollTo(0, y);
          await new Promise((resolve) => setTimeout(resolve, 150));
        }
      });
      await page.waitForTimeout(800);

      for (const alt of ALT[locale]) {
        const shot = page.getByRole("img", { name: alt });
        // Both themes are in the markup; only the displayed one is in the accessibility tree.
        await expect(shot).toHaveCount(1);
        await expect(shot).toBeVisible();
        expect(
          await shot.evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth > 0),
        ).toBe(true);
      }

      // A message the page still asks for but the catalogue no longer has renders as its own key ("home.chat.mockOnline"): the
      // compact mobile mockups in the sections read some of the same namespaces, and are in the markup at every width.
      await expect(page.locator("body")).not.toContainText(
        /\bhome\.(clients|program|chat|shots|demo)\.\w+/,
      );

      expect(fetched.length).toBe(3);
      for (const url of fetched) {
        expect(url).toContain(`-${locale}-${theme}.webp`);
      }
    });
  }
}

test("switching the theme swaps the capture without a reload", async ({ page }) => {
  await page.addInitScript(() => {
    try {
      localStorage.setItem("lifey-theme", "dark");
    } catch {
      /* storage off */
    }
  });
  await page.goto("/en/for-trainers");
  const clients = page.getByRole("img", { name: /A client's overview/ });
  await clients.scrollIntoViewIfNeeded();
  await expect(clients).toBeVisible();
  expect(
    await clients.evaluate((img: HTMLImageElement) => decodeURIComponent(img.currentSrc)),
  ).toContain("clients-en-dark.webp");

  await page.evaluate(() => document.documentElement.setAttribute("data-theme", "light"));

  await expect(clients).toBeVisible();
  await expect
    .poll(() => clients.evaluate((img: HTMLImageElement) => decodeURIComponent(img.currentSrc)))
    .toContain("clients-en-light.webp");
});
