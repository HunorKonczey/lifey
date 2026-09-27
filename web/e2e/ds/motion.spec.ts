import { test, expect } from "@playwright/test";

/**
 * AnimatedNumber / AnimatedFill (D-W0.13, W0.6) against the gallery's
 * "Motion" section demo, which exists exactly to make these three behaviours
 * checkable in a real browser:
 *  - a re-render with the same value never starts a rAF loop;
 *  - reduced motion jumps to the final value instead of counting up;
 *  - the count/fill genuinely animates otherwise (the contrasting case,
 *    so the reduced-motion assertion isn't trivially true because nothing
 *    would have animated anyway).
 */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
});

test("re-rendering AnimatedNumber with the same value never changes the displayed text", async ({ page }) => {
  // A global rAF-call counter is too noisy in a real app (devtools, analytics
  // and React's own scheduler all call it for unrelated reasons) — instead,
  // sample the actual rendered text repeatedly and assert it never so much as
  // flickers, which is the only thing a spurious animation could produce.
  const before = await page.getByTestId("animated-number").innerText();

  await page.getByTestId("animated-number-same").click();

  for (let i = 0; i < 8; i++) {
    await page.waitForTimeout(25);
    expect(await page.getByTestId("animated-number").innerText()).toBe(before);
  }
});

test("AnimatedNumber genuinely animates when the value changes (the contrasting case)", async ({ page }) => {
  const before = await page.getByTestId("animated-number").innerText();

  await page.getByTestId("animated-number-change").click();
  // Sampled mid-flight (durationMs=600) — not yet the final value.
  await page.waitForTimeout(50);
  const midFlight = await page.getByTestId("animated-number").innerText();
  expect(midFlight).not.toBe(before);

  await page.waitForTimeout(700);
  const final = await page.getByTestId("animated-number").innerText();
  expect(Number(final.replace(/,/g, ""))).toBe(Number(before.replace(/,/g, "")) + 137);
});

test("reduced motion jumps AnimatedNumber to the final value immediately", async ({ page }) => {
  await page.getByLabel("Reduced motion").check();
  await expect(page.locator("html")).toHaveAttribute("data-force-reduced-motion", "true");

  const before = await page.getByTestId("animated-number").innerText();
  await page.getByTestId("animated-number-change").click();

  // One rAF tick, not 600ms of easing — settled well within a frame budget.
  await page.waitForTimeout(50);
  const after = await page.getByTestId("animated-number").innerText();
  expect(Number(after.replace(/,/g, ""))).toBe(Number(before.replace(/,/g, "")) + 137);
});

test("AnimatedFill animates the difference, not a reset to 0", async ({ page }) => {
  const before = await page.getByTestId("animated-fill-bar").evaluate((el) => el.style.width);

  await page.getByTestId("animated-fill-change").click();
  await page.waitForTimeout(50);
  const midFlight = await page.getByTestId("animated-fill-bar").evaluate((el) => el.style.width);

  // Mid-flight it should be moving toward the new value from wherever it
  // already was — never snapping back down to 0% first.
  expect(parseFloat(midFlight)).toBeGreaterThan(0);
  expect(midFlight).not.toBe(before);

  await page.waitForTimeout(1000);
  const final = await page.getByTestId("animated-fill-bar").evaluate((el) => el.style.width);
  expect(parseFloat(final)).toBeGreaterThan(parseFloat(before));
});
