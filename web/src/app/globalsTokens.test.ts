import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

/**
 * A `var(--x)` with no `--x` behind it does not fail - the property is just invalid at computed-value time, so a band
 * that should be `--nested` renders transparent. The marketing tokens (68 §2.3, LIF-118) are the newest and the easiest
 * to mistype, so every `--mkt-*` a component reads must be defined in globals.css.
 */

const SRC = join(dirname(fileURLToPath(import.meta.url)), "..");
// Comments dropped: globals.css explains the tokens in prose that also contains "--mkt-x:".
const css = readFileSync(join(SRC, "app", "globals.css"), "utf8").replace(/\/\*[\s\S]*?\*\//g, "");

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return /\.(tsx?|css)$/.test(name) && !/\.test\./.test(name) ? [path] : [];
  });
}

describe("marketing tokens", () => {
  const defined = new Set([...css.matchAll(/^\s*(--mkt-[a-z-]+)\s*:/gm)].map((m) => m[1]));
  const used = new Set(
    sourceFiles(SRC).flatMap((file) => [...readFileSync(file, "utf8").matchAll(/var\((--mkt-[a-z-]+)/g)].map((m) => m[1]))
  );

  it("defines the tokens the shipped pages use", () => {
    expect([...defined].sort()).toEqual(["--mkt-section-alt", "--mkt-shadow-lift"]);
  });

  it("every --mkt-* a component reads is defined", () => {
    expect(used.size).toBeGreaterThan(0);
    for (const token of used) expect(defined, token).toContain(token);
  });
});
