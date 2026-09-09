/**
 * Renders the store screenshot set straight out of the design canvas
 * (docs/landing_page/design/Lifey Paywall.dc.html, frames P18–P23 + P25) at the
 * exact pixel sizes App Store Connect and the Play Console demand.
 *
 * Why render rather than crop an export: the frames are HTML, so scaling them
 * to a store size re-renders the text as vectors instead of enlarging a bitmap.
 * A 440 px design becomes a crisp 1290 px screenshot with no resampling.
 *
 * Usage (from the repo root):
 *
 *   node devops/export-store-screenshots.mjs
 *   node devops/export-store-screenshots.mjs --out some/dir --only P18,P25
 *
 * Output: devops/store-assets/<size>/<frame>.png — gitignored, regenerate at
 * will. The copy that goes with them (titles, keywords, descriptions, the
 * privacy answers) is docs/landing_page/74-store-listing-and-aso.md.
 *
 * Requires Playwright's chromium, which the web app already depends on:
 * `cd web && npx playwright install chromium` if it is missing.
 */
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { mkdir } from 'node:fs/promises';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..');
const { chromium } = await import(
  pathToFileURL(join(repoRoot, 'web', 'node_modules', 'playwright', 'index.mjs')).href
);

const CANVAS = join(repoRoot, 'docs', 'landing_page', 'design', 'Lifey Paywall.dc.html');

/**
 * The sizes each store actually accepts. Apple wants one set per device class
 * it lists; Play wants phone screenshots plus the feature graphic.
 *
 * `pad` is the breathing room around the frame inside the canvas — the design
 * already carries its own padding, so this is small on purpose.
 */
const TARGETS = [
  { dir: 'apple-6.9', width: 1290, height: 2796, pad: 0, frames: 'screenshots' },
  { dir: 'apple-6.5', width: 1242, height: 2688, pad: 0, frames: 'screenshots' },
  { dir: 'play-phone', width: 1080, height: 1920, pad: 24, frames: 'screenshots' },
  { dir: 'play-feature-graphic', width: 1024, height: 500, pad: 0, frames: 'feature' },
];

const SCREENSHOT_FRAMES = ['P18', 'P19', 'P20', 'P21', 'P22', 'P23'];
const FEATURE_FRAMES = ['P25'];

const args = process.argv.slice(2);
const argValue = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const outRoot = resolve(repoRoot, argValue('--out') ?? join('devops', 'store-assets'));
const only = argValue('--only')?.split(',').map((s) => s.trim());

const browser = await chromium.launch();
const page = await browser.newPage();

await page.goto(pathToFileURL(CANVAS).href);

// The canvas keeps its font <link>s inside a <helmet> element that its own
// support.js normally hoists. That file is not in the repo, so do it here —
// without it every frame renders in a fallback font and the icon glyphs come
// out as their ligature text ("check", "lock", ...), which is the same class of
// bug 68 §12.2 DV-11 records on the web side.
await page.evaluate(() => {
  document.querySelectorAll('helmet link, helmet style').forEach((n) => document.head.appendChild(n));
});
await page.waitForLoadState('networkidle');
await page.evaluate(() => document.fonts.ready);

let written = 0;
for (const target of TARGETS) {
  const frames = (target.frames === 'feature' ? FEATURE_FRAMES : SCREENSHOT_FRAMES)
    .filter((f) => !only || only.includes(f));
  if (frames.length === 0) continue;

  await mkdir(join(outRoot, target.dir), { recursive: true });
  await page.setViewportSize({ width: target.width, height: target.height });

  for (const frame of frames) {
    // Re-read the canvas for every frame: the layout below detaches the frame
    // from its siblings, so the page cannot be reused.
    await page.goto(pathToFileURL(CANVAS).href);
    await page.evaluate(() => {
      document.querySelectorAll('helmet link, helmet style').forEach((n) => document.head.appendChild(n));
    });
    await page.evaluate(() => document.fonts.ready);

    const ok = await page.evaluate(
      ({ label, width, height, pad }) => {
        const el = document.querySelector(`[data-screen-label="${label}"]`);
        if (!el) return false;

        // Detach first, then clear: the reference survives, its siblings do not.
        el.remove();
        document.body.innerHTML = '';
        document.body.style.cssText =
          `margin:0;width:${width}px;height:${height}px;background:#161611;` +
          'display:flex;align-items:center;justify-content:center;overflow:hidden;' +
          // The frames inherit the typeface from the canvas wrapper they are
          // being lifted out of; without this they render in the browser's
          // default serif and every screenshot is off-brand.
          "font-family:'Plus Jakarta Sans',sans-serif;";

        const wrap = document.createElement('div');
        wrap.appendChild(el);
        document.body.appendChild(wrap);

        const rect = el.getBoundingClientRect();
        const scale = Math.min((width - 2 * pad) / rect.width, (height - 2 * pad) / rect.height);
        wrap.style.cssText = `transform:scale(${scale});transform-origin:center center;`;
        return true;
      },
      { label: frame, width: target.width, height: target.height, pad: target.pad }
    );

    if (!ok) {
      console.error(`  MISSING  ${frame} — no [data-screen-label="${frame}"] in the canvas`);
      continue;
    }

    const path = join(outRoot, target.dir, `${frame}.png`);
    await page.screenshot({ path, clip: { x: 0, y: 0, width: target.width, height: target.height } });
    console.log(`  ${target.dir.padEnd(22)} ${frame}  ${target.width}x${target.height}`);
    written += 1;
  }
}

await browser.close();
console.log(`\n${written} file(s) written to ${outRoot}`);
console.log(
  'English set: not exportable yet — the canvas carries EN captions only as the P24 contact\n' +
    'sheet (thumbnails, simplified content), not as six full frames. See\n' +
    'docs/landing_page/74-store-listing-and-aso.md §4.'
);
