/**
 * WCAG 2.x contrast helpers — a port of
 * `mobile/lib/core/theme/contrast.dart`, kept function-for-function so both
 * clients guard the same v2 palette (D-W0.4) with the same math.
 */

export interface Rgb {
  r: number;
  g: number;
  b: number;
}

/** Parses `#rgb` or `#rrggbb`. Alpha, if present in `#rrggbbaa`, is ignored —
 * callers blend translucent colours explicitly via {@link alphaBlend}. */
export function parseHex(hex: string): Rgb {
  const value = hex.replace("#", "");
  const expand = value.length === 3
    ? value.split("").map((c) => c + c).join("")
    : value;
  const int = parseInt(expand.slice(0, 6), 16);
  return {
    r: (int >> 16) & 255,
    g: (int >> 8) & 255,
    b: int & 255,
  };
}

function srgbToLinear(channel: number): number {
  const c = channel / 255;
  return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

/** WCAG relative luminance of an sRGB colour, 0 (black) – 1 (white). */
export function relativeLuminance({ r, g, b }: Rgb): number {
  return 0.2126 * srgbToLinear(r) + 0.7152 * srgbToLinear(g) + 0.0722 * srgbToLinear(b);
}

/** [foreground] at [alpha] (0–1) composited over an opaque [background]. */
export function alphaBlend(foreground: Rgb, alpha: number, background: Rgb): Rgb {
  return {
    r: foreground.r * alpha + background.r * (1 - alpha),
    g: foreground.g * alpha + background.g * (1 - alpha),
    b: foreground.b * alpha + background.b * (1 - alpha),
  };
}

/** The fill a tinted chip draws: `color` at `alpha` over `surface`. */
export const tintOver = alphaBlend;

/** WCAG 2.x contrast ratio between two opaque colours, 1 – 21. A translucent
 * foreground must be composited with {@link alphaBlend} first, the way it
 * renders. */
export function contrastRatio(foreground: Rgb, background: Rgb): number {
  const fg = relativeLuminance(foreground);
  const bg = relativeLuminance(background);
  const hi = Math.max(fg, bg);
  const lo = Math.min(fg, bg);
  return (hi + 0.05) / (lo + 0.05);
}

/** Contrast ratio between two hex colours — the shape most tests want. */
export function hexContrastRatio(foreground: string, background: string): number {
  return contrastRatio(parseHex(foreground), parseHex(background));
}

/** Parses whatever `getComputedStyle` hands back for a CSS colour —
 * `rgb(r, g, b)` / `rgba(r, g, b, a)` (what a browser normalizes hex and
 * `color-mix()` values to) or a raw hex string. Used by the design gallery's
 * live contrast swatches (W0.5), which read actual computed values rather
 * than a hard-coded palette table. */
export function parseCssColor(value: string): Rgb {
  const trimmed = value.trim();
  if (trimmed.startsWith("#")) return parseHex(trimmed);
  const match = trimmed.match(/rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)/i);
  if (!match) throw new Error(`Unrecognized CSS colour: ${value}`);
  return { r: Number(match[1]), g: Number(match[2]), b: Number(match[3]) };
}
