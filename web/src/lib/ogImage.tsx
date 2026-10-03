import { ImageResponse } from "next/og";

export const OG_IMAGE_SIZE = { width: 1200, height: 630 };
export const OG_IMAGE_CONTENT_TYPE = "image/png";

/**
 * One rendering function every marketing page's own `opengraph-image.tsx`
 * calls (docs/landing_page/65 §5.1: "opengraph-image.tsx per page... so the
 * brand image is never a stale PNG someone forgot to re-export"). Next.js
 * requires the file itself to live inside each route segment to be picked
 * up — this just keeps the actual design in one place instead of eleven
 * copies. Dark palette only (68 D-DW2: "dark is the hero") — a social-share
 * card doesn't have a light/dark visitor preference to honor, it's one
 * fixed image.
 */
// The hexes are the v2 *dark* tokens (--bg, --text, --primary — globals.css, D-W0.4): Satori renders outside the
// page, so it cannot read the CSS variables and the values are copied by hand.
export function renderOgImage({ eyebrow, title }: { eyebrow: string; title: string }) {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          padding: "80px 96px",
          background: "#12130E",
          color: "#F2F1E6",
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
          <div
            style={{
              width: 56,
              height: 56,
              borderRadius: 14,
              background: "#B5C47C",
              display: "flex",
            }}
          />
          <span style={{ fontSize: 36, fontWeight: 800 }}>Lifey</span>
        </div>

        <div
          style={{
            display: "flex",
            fontSize: 24,
            fontWeight: 800,
            letterSpacing: 2,
            color: "#B5C47C",
            marginTop: 56,
            textTransform: "uppercase",
          }}
        >
          {eyebrow}
        </div>
        {/* Known cosmetic quirk (documented in 65 Prompt 9's landed notes,
            not chased further): Satori's default fallback font renders a
            visibly wide gap around certain word boundaries (e.g. "helyett
            egy") even though the source string has exactly one space
            character — confirmed by char-code inspection, not a data bug.
            Sizing chosen to keep most titles on one line, which is the
            only mitigation attempted; a real embedded font file would be
            the actual fix, not attempted here. */}
        <div
          style={{
            display: "flex",
            fontSize: 54,
            fontWeight: 800,
            lineHeight: 1.2,
            marginTop: 16,
            width: 1020,
          }}
        >
          {title}
        </div>
      </div>
    ),
    { ...OG_IMAGE_SIZE }
  );
}
