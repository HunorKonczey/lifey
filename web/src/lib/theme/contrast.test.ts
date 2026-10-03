import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { describe, expect, it } from "vitest";
import { contrastRatio, hexContrastRatio, parseCssColor, parseHex, relativeLuminance, tintOver } from "./contrast";

const AA = 4.5;

describe("relativeLuminance", () => {
  it("is 0 for black and 1 for white", () => {
    expect(relativeLuminance(parseHex("#000000"))).toBeCloseTo(0, 5);
    expect(relativeLuminance(parseHex("#FFFFFF"))).toBeCloseTo(1, 5);
  });
});

describe("contrastRatio", () => {
  it("is 21 for black on white", () => {
    expect(contrastRatio(parseHex("#000000"), parseHex("#FFFFFF"))).toBeCloseTo(21, 1);
  });
  it("is 1 for a colour against itself", () => {
    expect(hexContrastRatio("#9DAE6B", "#9DAE6B")).toBeCloseTo(1, 5);
  });
  it("is symmetric", () => {
    expect(hexContrastRatio("#12130E", "#F2F1E6")).toBeCloseTo(hexContrastRatio("#F2F1E6", "#12130E"), 5);
  });
});

describe("parseCssColor", () => {
  it("parses rgb() and rgba(), as getComputedStyle normalizes hex/color-mix to", () => {
    expect(parseCssColor("rgb(26, 28, 21)")).toEqual({ r: 26, g: 28, b: 21 });
    expect(parseCssColor("rgba(26, 28, 21, 0.5)")).toEqual({ r: 26, g: 28, b: 21 });
  });

  it("still parses a raw hex string", () => {
    expect(parseCssColor("#1A1C15")).toEqual(parseHex("#1A1C15"));
  });
});

describe("tintOver", () => {
  it("returns the surface at alpha 0 and the colour at alpha 1", () => {
    const surface = parseHex("#1A1C15");
    const color = parseHex("#93C98C");
    expect(tintOver(color, 0, surface)).toEqual(surface);
    expect(tintOver(color, 1, surface)).toEqual(color);
  });
});

// ─── D-W0.4 palette guard ───────────────────────────────────────────────
// The v2 hexes, exactly as declared in globals.css (D-W0.4). Duplicated here
// as literals (rather than re-parsed) for the palette-shape assertions below;
// the token-map tests further down parse globals.css directly so a value
// drifting from this table without the CSS changing to match is still caught
// by loadTokens() disagreeing with someone reading the two side by side.
const dark = {
  bg: "#12130E",
  card: "#1A1C15",
  nested: "#22251C",
  control: "#2C2F24",
  raised: "#36392D",
  text: "#F2F1E6",
  text2: "#B6B5A5",
  text3: "#8F8F80",
  primary: "#B5C47C",
  onPrimary: "#1A1F0A",
  onPrimaryTint: "#D6E2A6",
  metrics: {
    kcal: "#EC9A66",
    protein: "#93C98C",
    carbs: "#E2BE62",
    fat: "#A3A1DB",
    water: "#74B6D6",
    steps: "#C593CC",
    weight: "#98ADC0",
    heart: "#E07F76",
  },
};

const light = {
  bg: "#F4F2E9",
  card: "#FFFFFF",
  nested: "#F0EEE3",
  control: "#E6E4D6",
  raised: "#DCDAC9",
  text: "#1C1D16",
  text2: "#56574B",
  text3: "#6B6C5F",
  primary: "#4E6530",
  onPrimary: "#FFFFFF",
  metrics: {
    kcal: "#9D4602",
    protein: "#34742F",
    carbs: "#7F5D00",
    fat: "#5A57A8",
    water: "#1A6C8F",
    steps: "#83488D",
    weight: "#50667A",
    heart: "#A73831",
  },
};

describe("dark palette", () => {
  it("text tiers keep their hierarchy on bg", () => {
    expect(hexContrastRatio(dark.text, dark.bg)).toBeGreaterThanOrEqual(15);
    expect(hexContrastRatio(dark.text2, dark.bg)).toBeGreaterThanOrEqual(8.5);
    expect(hexContrastRatio(dark.text3, dark.bg)).toBeGreaterThanOrEqual(5.5);
  });

  it("every text tier is AA on every surface it sits on", () => {
    for (const surface of [dark.bg, dark.card, dark.nested]) {
      for (const text of [dark.text, dark.text2, dark.text3]) {
        expect(hexContrastRatio(text, surface)).toBeGreaterThanOrEqual(AA);
      }
    }
  });

  it("onPrimary on primary is AA", () => {
    expect(hexContrastRatio(dark.onPrimary, dark.primary)).toBeGreaterThanOrEqual(8.5);
  });

  it("primary-tint text is AA on its own tint over card", () => {
    const tint = tintOver(parseHex(dark.primary), 0.16, parseHex(dark.card));
    expect(contrastRatio(parseHex(dark.onPrimaryTint), tint)).toBeGreaterThanOrEqual(AA);
  });

  it("every metric is AA on card and on its own 16% chip tint", () => {
    for (const hex of Object.values(dark.metrics)) {
      const metric = parseHex(hex);
      expect(contrastRatio(metric, parseHex(dark.card))).toBeGreaterThanOrEqual(AA);
      const tint = tintOver(metric, 0.16, parseHex(dark.card));
      expect(contrastRatio(metric, tint)).toBeGreaterThanOrEqual(AA);
    }
  });

  it("the surface ladder rises monotonically", () => {
    const ladder = [dark.bg, dark.card, dark.nested, dark.control, dark.raised].map((hex) =>
      relativeLuminance(parseHex(hex)),
    );
    for (let i = 1; i < ladder.length; i++) {
      expect(ladder[i]).toBeGreaterThan(ladder[i - 1]);
    }
  });
});

describe("light palette", () => {
  it("text tiers keep their hierarchy on bg", () => {
    expect(hexContrastRatio(light.text, light.bg)).toBeGreaterThanOrEqual(15);
    expect(hexContrastRatio(light.text2, light.bg)).toBeGreaterThanOrEqual(6.5);
    expect(hexContrastRatio(light.text3, light.bg)).toBeGreaterThanOrEqual(4.7);
  });

  it("every text tier is AA on every surface it sits on", () => {
    for (const surface of [light.bg, light.card, light.nested]) {
      for (const text of [light.text, light.text2, light.text3]) {
        expect(hexContrastRatio(text, surface)).toBeGreaterThanOrEqual(AA);
      }
    }
  });

  it("onPrimary on primary is AA", () => {
    expect(hexContrastRatio(light.onPrimary, light.primary)).toBeGreaterThanOrEqual(6.5);
  });

  it("primary-tint text (primary itself, D-W0.4) is AA on its own tint over card", () => {
    const tint = tintOver(parseHex(light.primary), 0.12, parseHex(light.card));
    expect(contrastRatio(parseHex(light.primary), tint)).toBeGreaterThanOrEqual(AA);
  });

  it("every metric is AA on bg, on card, and on its own 12% chip tint", () => {
    for (const hex of Object.values(light.metrics)) {
      const metric = parseHex(hex);
      expect(contrastRatio(metric, parseHex(light.bg))).toBeGreaterThanOrEqual(AA);
      expect(contrastRatio(metric, parseHex(light.card))).toBeGreaterThanOrEqual(AA);
      const tint = tintOver(metric, 0.12, parseHex(light.card));
      expect(contrastRatio(metric, tint)).toBeGreaterThanOrEqual(4.8);
    }
  });

  it("the surface ladder darkens with nesting, card stays white", () => {
    expect(light.card).toBe("#FFFFFF");
    const ladder = [light.card, light.nested, light.control, light.raised].map((hex) =>
      relativeLuminance(parseHex(hex)),
    );
    for (let i = 1; i < ladder.length; i++) {
      expect(ladder[i]).toBeLessThan(ladder[i - 1]);
    }
  });
});

it("protein is no longer the brand primary (D-W0.3 — the second green disappears)", () => {
  expect(dark.metrics.protein).not.toBe(dark.primary);
  expect(light.metrics.protein).not.toBe(light.primary);
});

// ─── Token-map tests: parse globals.css directly, no browser needed ───────
// Confirms the v2 tokens landed in the stylesheet and the legacy names are gone from the app scope (W10.3),
// independent of the literal tables above.

const cssPath = join(dirname(fileURLToPath(import.meta.url)), "../../app/globals.css");
const css = readFileSync(cssPath, "utf-8");

function extractBlock(selectorWithBrace: string): string {
  const start = css.indexOf(selectorWithBrace);
  if (start === -1) throw new Error(`selector not found in globals.css: ${selectorWithBrace}`);
  const braceStart = start + selectorWithBrace.length - 1;
  const braceEnd = css.indexOf("}", braceStart);
  return css.slice(braceStart + 1, braceEnd);
}

function parseDeclarations(block: string): Map<string, string> {
  const map = new Map<string, string>();
  const re = /--([\w-]+)\s*:\s*([^;]+);/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(block))) {
    map.set(match[1], match[2].trim());
  }
  return map;
}

function resolve(name: string, raw: Map<string, string>, cache = new Map<string, string>()): string | undefined {
  if (cache.has(name)) return cache.get(name);
  const value = raw.get(name);
  if (!value) return undefined;
  const varMatch = value.match(/^var\(--([\w-]+)\)$/);
  if (varMatch) {
    const resolved = resolve(varMatch[1], raw, cache);
    if (resolved) cache.set(name, resolved);
    return resolved;
  }
  if (/^#[0-9a-fA-F]{3,8}$/.test(value)) {
    cache.set(name, value);
    return value;
  }
  return undefined; // color-mix()/rgba() etc. — not needed by these tests
}

describe("globals.css token map (D-W0.3)", () => {
  const rootRaw = parseDeclarations(extractBlock(":root {"));
  const lightRaw = new Map([...rootRaw, ...parseDeclarations(extractBlock('[data-theme="light"] {'))]);

  it("the legacy variable names are no longer defined in the app scope", () => {
    for (const name of ["tertiary", "secondary", "surface", "surface-container", "on-surface", "muted", "metric-kcal", "r-lg", "shadow-float"]) {
      expect(rootRaw.has(name), name).toBe(false);
      expect(lightRaw.has(name), name).toBe(false);
    }
  });

  it("the app scope's resolved dark tokens match the D-W0.4 table", () => {
    expect(resolve("bg", rootRaw)?.toUpperCase()).toBe(dark.bg);
    expect(resolve("primary", rootRaw)?.toUpperCase()).toBe(dark.primary);
    expect(resolve("m-protein", rootRaw)?.toUpperCase()).toBe(dark.metrics.protein);
  });

  it("the app scope's resolved light tokens match the D-W0.4 table", () => {
    expect(resolve("bg", lightRaw)?.toUpperCase()).toBe(light.bg);
    expect(resolve("primary", lightRaw)?.toUpperCase()).toBe(light.primary);
    expect(resolve("m-protein", lightRaw)?.toUpperCase()).toBe(light.metrics.protein);
  });

  it("the marketing pin is gone: no block scopes legacy values under data-surface (D-W0.2 retired)", () => {
    expect(css).not.toContain('[data-surface="marketing"]');
    // None of the legacy variable names is defined anywhere any more.
    for (const name of ["surface", "surface-container", "surface-high", "on-surface", "on-surface-variant", "muted", "secondary", "tertiary", "metric-kcal", "goal-positive"]) {
      expect(css, name).not.toMatch(new RegExp(`--${name}\s*:`));
    }
  });
});
