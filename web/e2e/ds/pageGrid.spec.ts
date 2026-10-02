import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** D-W0.6's `PageGrid` against the gallery's "Page grid" section: 4 / 8 / 12
 *  columns and gaps per breakpoint, spans honoured, order flipped at md. */

function section(page: Page) {
  return page.locator("#page-grid");
}

async function gridInfo(page: Page) {
  return section(page)
    .locator(".page-grid")
    .evaluate((el) => {
      const cs = getComputedStyle(el);
      const items = [...el.children].map((c) => {
        const r = c.getBoundingClientRect();
        return { text: (c as HTMLElement).innerText.trim(), width: r.width, top: r.top, left: r.left };
      });
      return { cols: cs.gridTemplateColumns.split(" ").length, gap: cs.columnGap, items };
    });
}

test("12 columns and a 24px gap at 1440, main 8 beside side 4", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  const info = await gridInfo(page);
  expect(info.cols).toBe(12);
  expect(info.gap).toBe("24px");
  const main = info.items.find((i) => i.text === "main 8")!;
  const side = info.items.find((i) => i.text === "side 4")!;
  expect(side.top).toBe(main.top); // same row
  expect(main.width / side.width).toBeCloseTo(2.06, 1); // 8 cols vs 4 cols, one extra gap
});

test("12 columns and a 20px gap at 1280", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto("/dev/design");
  const info = await gridInfo(page);
  expect(info.cols).toBe(12);
  expect(info.gap).toBe("20px");
});

test("8 columns at 1024: full-width block comes before the side panel", async ({ page }) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.goto("/dev/design");
  const info = await gridInfo(page);
  expect(info.cols).toBe(8);
  const full = info.items.find((i) => i.text === "full")!;
  const side = info.items.find((i) => i.text === "side 4")!;
  expect(full.top).toBeLessThan(side.top);
});

test("4 columns at 390: every block stacks full width", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/design");
  const info = await gridInfo(page);
  expect(info.cols).toBe(4);
  expect(info.gap).toBe("12px");
  const widths = new Set(info.items.map((i) => Math.round(i.width)));
  expect(widths.size).toBe(1);
});
