import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The water tile's SegmentBar (W1.5, D-W0.13): first appearance fills from
 *  0, and a later change animates only the difference — already-full segments
 *  never empty and refill — settling into the resting shapes. */

/** Each segment's fill as a 0–1 fraction. */
async function fills(page: Page): Promise<number[]> {
  return page.getByTestId("segment-demo").evaluate((el) =>
    [...el.firstElementChild!.children].map((seg) => {
      const fill = seg.firstElementChild as HTMLElement | null;
      return fill ? parseFloat(fill.style.width) / 100 : 0;
    }),
  );
}

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Progress", exact: true }).scrollIntoViewIfNeeded();
  await page.waitForTimeout(1200); // let the first fill finish
});

test("at rest: 40% is four full segments and nothing else", async ({ page }) => {
  expect(await fills(page)).toEqual([1, 1, 1, 1, 0, 0, 0, 0, 0, 0]);
});

test("adding animates only the difference and settles into full + one 45% partial", async ({ page }) => {
  await page.getByTestId("segment-demo-add").click();
  await page.waitForTimeout(250);
  const mid = await fills(page);
  // the four that were already full stay full — no reset to empty
  expect(mid.slice(0, 4)).toEqual([1, 1, 1, 1]);
  // and the new amount is still on its way
  const midTotal = mid.reduce((a, b) => a + b, 0);
  expect(midTotal).toBeGreaterThan(4);
  expect(midTotal).toBeLessThan(6.5);

  await page.waitForTimeout(1100);
  expect(await fills(page)).toEqual([1, 1, 1, 1, 1, 1, 0.45, 0, 0, 0]);
});
