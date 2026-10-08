import { test, expect, type Page } from "@playwright/test";

/**
 * WCAG 2.4.11 Focus Not Obscured on the phone layout (LIF-138): at 200 % zoom a 1280×800 window is 640×400 CSS px, which
 * is the phone shell — a sticky header on top, a fixed bottom nav (and a floating action button) at the foot. Tabbing
 * used to scroll a control only as far as the viewport edge, i.e. under one of them. `scroll-padding` on <html>
 * (globals.css, fed by MobileHeader's `--app-header-h`) keeps focus clear of both.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";

test.use({ viewport: { width: 640, height: 450 } });

/** The element in focus, and whatever is painted on top of its centre when that is not the element itself. */
async function obscuredBy(page: Page) {
  return page.evaluate(() => {
    const el = document.activeElement as HTMLElement | null;
    if (!el || el === document.body || el.tagName === "NEXTJS-PORTAL") return null;
    const box = el.getBoundingClientRect();
    const x = Math.min(Math.max(box.left + box.width / 2, 1), innerWidth - 1);
    const y = Math.min(Math.max(box.top + box.height / 2, 1), innerHeight - 1);
    const top = document.elementFromPoint(x, y);
    const covered = top && !el.contains(top) && !top.contains(el) && top.tagName !== "NEXTJS-PORTAL";
    const label = (el.getAttribute("aria-label") || el.innerText || el.tagName).replace(/\s+/g, " ").slice(0, 40);
    return covered ? `${label} — under <${(top.closest("nav,header") ?? top).tagName.toLowerCase()}>` : null;
  });
}

test("tabbing through a long phone-layout page never leaves the focused control under the header or the bottom nav", async ({ page, request }) => {
  const email = `e2e-focus-${Date.now()}@example.com`;
  const password = "E2eFocus123!";
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password, firstName: "E2E", lastName: "Focus" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|onboarding/);
  await page.goto("/settings");
  await expect(page.getByRole("navigation", { name: "Main navigation" })).toBeVisible();

  const hidden: string[] = [];
  let stops = 0;
  for (let i = 0; i < 40; i++) {
    await page.keyboard.press("Tab");
    stops++;
    const hit = await obscuredBy(page);
    if (hit) hidden.push(`Tab ${i + 1}: ${hit}`);
  }
  for (let i = 0; i < 40; i++) {
    await page.keyboard.press("Shift+Tab");
    const hit = await obscuredBy(page);
    if (hit) hidden.push(`Shift+Tab ${i + 1}: ${hit}`);
  }
  expect(stops).toBeGreaterThan(20);
  expect(hidden, "focused controls hidden behind the sticky header or the bottom nav").toEqual([]);
});
