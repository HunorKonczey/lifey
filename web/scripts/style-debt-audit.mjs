#!/usr/bin/env node
/**
 * Style-debt audit (docs/redesign-web/78-web-redesign-plan.md W10.1): counts what is still on the old design
 * system in the app scope of `src/` (marketing is excluded - it keeps its own pinned copy of the old values).
 *
 * Hard rules (exit code 1 when any is above zero):
 *   legacy-var     a legacy CSS variable from the D-W0.3 table, as `var(--surface)`, `--tertiary` ...
 *   legacy-import  an import from `components/ui`, `components/data` or the old `components/layout` shell
 *   native-date    `type="date"` / `type="time"` inputs (the DS fields replace them)
 *   legacy-radius  a Tailwind arbitrary radius on the old --r-sm, --r-md, --r-input, --r-lg or --r-nav variable
 *
 * Soft counts (reported, never fail): hex literals, inline `style={{` with a colour / radius / font-size,
 * `date-fns` `format(` in components, `.toFixed(` in components, `humanizeEnum(`.
 *
 * Usage: `npm run audit:styles` (all files with hits), `npm run audit:styles -- --summary` (totals only).
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

const ROOT = new URL("../src/", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const SUMMARY_ONLY = process.argv.includes("--summary");

const EXCLUDED_DIRS = [
  ["components", "marketing"],
  ["app", "(marketing)"],
  ["app", "(marketing-bare)"],
  ["components", "ds", "gallery"], // the dev gallery shows the old values on purpose where it documents them
];

const LEGACY_VARS = [
  "surface", "surface-container", "surface-high", "surface-highest", "on-surface", "on-surface-variant", "muted",
  "secondary", "tertiary", "tertiary-container", "on-tertiary-container", "border", "error", "error-container",
  "metric-kcal", "metric-protein", "metric-carbs", "metric-fat", "metric-water", "metric-steps", "metric-weight",
  "metric-hr", "goal-positive", "goal-negative", "r-sm", "r-md", "r-input", "r-lg", "r-nav", "shadow-float",
];
const legacyVar = new RegExp(`var\\(--(?:${LEGACY_VARS.join("|")})\\)`, "g");

const RULES = [
  { id: "legacy-var", hard: true, re: legacyVar },
  { id: "legacy-import", hard: true, re: /from\s+["']@\/components\/(?:ui|data|layout)(?:\/[^"']*)?["']/g },
  { id: "native-date", hard: true, re: /type=["'](?:date|time)["']/g },
  { id: "legacy-radius", hard: true, re: /rounded-\[var\(--r-(?:sm|md|input|lg|nav)\)\]/g },
  { id: "legacy-class", hard: true, re: /(?:bg|text|border|ring|from|to|via|fill|stroke|divide|outline|shadow)-(?:surface(?:-container|-high|-highest)?|secondary|tertiary(?:-container)?|on-tertiary-container|on-surface(?:-variant)?|muted|error(?:-container)?|metric-[a-z]+)/g },
  { id: "hex", hard: false, re: /#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b(?![0-9a-fA-F])/g },
  { id: "inline-style", hard: false, re: /style=\{\{[^}]*(?:color|background|borderRadius|fontSize)[^}]*\}\}/g },
  { id: "date-fns-format", hard: false, re: /\bformat\(\s*(?:new Date|[a-zA-Z_.]+,\s*["'])/g, jsxOnly: true },
  { id: "toFixed", hard: false, re: /\.toFixed\(/g, jsxOnly: true },
  { id: "humanizeEnum", hard: false, re: /humanizeEnum\(/g },
];

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) yield* walk(full);
    else if (/\.(tsx?|css)$/.test(name) && !/\.test\.tsx?$/.test(name)) yield full;
  }
}

function excluded(rel) {
  const parts = rel.split(sep);
  return EXCLUDED_DIRS.some((ex) => ex.every((seg, i) => parts[i] === seg));
}

const totals = Object.fromEntries(RULES.map((r) => [r.id, 0]));
const perFile = new Map();

for (const file of walk(ROOT)) {
  const rel = relative(ROOT, file);
  if (excluded(rel)) continue;
  // The token definitions themselves (globals.css) are the old system's home until W10.3 deletes the aliases.
  if (rel.split(sep).join("/") === "app/globals.css") continue;
  // Comments may talk about the old names (and `<input type="date">`); only code counts.
  const text = readFileSync(file, "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^\s*\/\/.*$/gm, "");
  const isTsx = file.endsWith(".tsx");
  for (const rule of RULES) {
    if (rule.jsxOnly && !isTsx) continue;
    const n = (text.match(rule.re) ?? []).length;
    if (n === 0) continue;
    totals[rule.id] += n;
    const entry = perFile.get(rel) ?? {};
    entry[rule.id] = n;
    perFile.set(rel, entry);
  }
}

if (!SUMMARY_ONLY) {
  for (const [rel, counts] of [...perFile].sort(([a], [b]) => a.localeCompare(b))) {
    console.log(`${rel.split(sep).join("/")}  ${Object.entries(counts).map(([k, v]) => `${k}=${v}`).join(" ")}`);
  }
  console.log("");
}
const hard = RULES.filter((r) => r.hard);
console.log("Hard rules (must be 0):");
for (const r of hard) console.log(`  ${r.id.padEnd(15)} ${totals[r.id]}`);
console.log("Soft counts:");
for (const r of RULES.filter((x) => !x.hard)) console.log(`  ${r.id.padEnd(15)} ${totals[r.id]}`);

const failing = hard.filter((r) => totals[r.id] > 0);
if (failing.length > 0) {
  console.error(`\nstyle-debt audit failed: ${failing.map((r) => `${r.id} (${totals[r.id]})`).join(", ")}`);
  process.exit(1);
}
console.log("\nstyle-debt audit passed");
