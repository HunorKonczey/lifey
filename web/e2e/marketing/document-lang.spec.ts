import { test, expect } from "@playwright/test";

/**
 * `<html lang>` follows the language the page is shown in (LIF-141, WCAG 3.1.1). The root layout renders
 * `lang="en"`; `DocumentLang` corrects it after hydration — from the URL segment on the marketing pages, from the
 * app's locale (the setting, else `navigator.language`) everywhere the app's providers are mounted. The login page is
 * such a page and needs no backend, so the browser language can be switched with `test.use({ locale })`.
 */
test.describe("document language", () => {
  test("the Hungarian marketing page is lang=hu, the English one lang=en", async ({ page }) => {
    await page.goto("/hu");
    await expect(page.locator("html")).toHaveAttribute("lang", "hu");
    await page.goto("/en");
    await expect(page.locator("html")).toHaveAttribute("lang", "en");
  });

  test.describe("browser language hu-HU", () => {
    test.use({ locale: "hu-HU" });
    test("the app's login page is lang=hu", async ({ page }) => {
      await page.goto("/login");
      await expect(page.locator("html")).toHaveAttribute("lang", "hu");
    });
  });

  test.describe("browser language en-US", () => {
    test.use({ locale: "en-US" });
    test("the app's login page is lang=en", async ({ page }) => {
      await page.goto("/login");
      await expect(page.locator("html")).toHaveAttribute("lang", "en");
    });
  });
});
