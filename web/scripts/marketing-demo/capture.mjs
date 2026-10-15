// Photographs the demo dataset for the marketing site (LIF-120, docs/landing_page/72 W12).
//
// Needs the seeded local stack - backend :8080, chat service :8081, Postgres :5432 - and the web dev server on :3000 started
// with NEXT_PUBLIC_CHAT_BASE_URL (the `web-chat` launch config), exactly as `e2e/README.md` describes. It seeds first (idempotent),
// logs in as the demo trainer, and writes WebP files to `public/marketing/shots/`:
//
//   <shot>-<locale>-<theme>.webp      shot: clients | program | chat      locale: hu | en      theme: dark | light
//
// 1280 x 800 at 1x: the pages show them at about 660 px wide, so that is already 1.9x on a 2x screen.
//
//   node scripts/marketing-demo/capture.mjs              # everything
//   node scripts/marketing-demo/capture.mjs hu dark      # one locale, one theme
//   node scripts/marketing-demo/capture.mjs --png <dir>  # PNG previews to <dir> instead (for looking at them)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";
import sharp from "sharp";
import { PASSWORD, UNIVERSES, seedAll } from "./seed.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const WEB = process.env.LIFEY_WEB ?? "http://localhost:3000";

const args = process.argv.slice(2);
const pngIdx = args.indexOf("--png");
const pngDir = pngIdx >= 0 ? args[pngIdx + 1] : null;
const rest = args.filter((a, i) => i !== pngIdx && i !== pngIdx + 1);
const locales = rest.filter((a) => a in UNIVERSES);
const themes = rest.filter((a) => a === "dark" || a === "light");
const outDir = pngDir ?? path.join(here, "..", "..", "public", "marketing", "shots");
fs.mkdirSync(outDir, { recursive: true });

const HIDE_DEV = () => {
  document.addEventListener("DOMContentLoaded", () => {
    const style = document.createElement("style");
    style.textContent = "nextjs-portal,.tsqd-open-btn-container{display:none!important}";
    document.head.appendChild(style);
  });
};

async function save(page, name) {
  await page.evaluate(() => document.fonts.ready).catch(() => {});
  await page.waitForTimeout(500);
  const png = await page.screenshot({ type: "png" });
  if (pngDir) fs.writeFileSync(path.join(outDir, `${name}.png`), png);
  else await sharp(png).webp({ quality: 82, effort: 5 }).toFile(path.join(outDir, `${name}.webp`));
  console.log("  ", name);
}

const seeded = await seedAll(locales.length ? locales : undefined);
const browser = await chromium.launch();

for (const [key, info] of Object.entries(seeded)) {
  for (const theme of themes.length ? themes : ["dark", "light"]) {
    const ctx = await browser.newContext({
      viewport: { width: 1120, height: 700 },
      deviceScaleFactor: 2,
      locale: key === "hu" ? "hu-HU" : "en-US",
      reducedMotion: "reduce",
    });
    await ctx.addInitScript(HIDE_DEV);
    await ctx.addInitScript((t) => {
      try { localStorage.setItem("lifey-theme", t); } catch { /* storage off */ }
    }, theme);
    const page = await ctx.newPage();
    await page.goto(`${WEB}/login`, { waitUntil: "domcontentloaded", timeout: 120000 });
    await page.locator("input[type=email]").fill(info.trainer.email);
    await page.locator("input[type=password]").fill(PASSWORD);
    await page.locator("button[type=submit]").click();
    await page.waitForURL("**/dashboard", { timeout: 120000 });

    console.log(`${key} / ${theme}`);

    // The sidebar says nothing about the product that the page itself does not: collapse it so the content gets the width. Below
    // about 1200 px the app does that by itself; at the wider window the programme grid needs, it has to be asked.
    const open = async (route, width, height, extraWait = 0) => {
      await page.setViewportSize({ width, height });
      await page.goto(`${WEB}${route}`, { waitUntil: "domcontentloaded", timeout: 120000 });
      await page.waitForTimeout(4000 + extraWait);
      const collapse = page.locator("button:has-text('left_panel_close')");
      if (await collapse.count()) {
        await collapse.first().click().catch(() => {});
        await page.waitForTimeout(900);
      }
    };

    await open(`/admin/clients/${info.anna.id}`, 1120, 700);
    await save(page, `clients-${key}-${theme}`);

    // The programme grid has seven day columns and does not fit 1120 px: a wider window for this one.
    await open(`/admin/programs/${info.programId}`, 1320, 760);
    await save(page, `program-${key}-${theme}`);

    await open(`/admin/chat?c=${info.conversationId}`, 1120, 700, 1500);
    await save(page, `chat-${key}-${theme}`);

    await ctx.close();
  }
}

await browser.close();
