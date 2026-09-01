/**
 * Lighthouse CI (docs/landing_page/65-web-landing-page-plan.md Prompt 11,
 * §8's performance budget). Runs against `/hu` only — §8's own budget table
 * is scoped to "the home page", and a full Lighthouse audit (real headless
 * Chrome, real network/CPU throttling) is too slow to repeat across all
 * eleven marketing routes on every CI run; `scripts/check-js-budget.mjs`
 * already covers every route for the (much faster) bundle-size half of the
 * budget.
 *
 * `next start` serves the build here despite `next.config.ts`'s
 * `output: "standalone"` (which prints a warning suggesting
 * `node .next/standalone/server.js` instead) — pre-existing, unrelated to
 * this prompt, and `next start` demonstrably serves the identical build
 * output (same HTML, same script tags, same bytes) that every manual
 * verification pass since Prompt 3 has measured against.
 *
 * Thresholds below are real numbers measured locally (headless Chrome,
 * mobile emulation + throttling, the actual `65` §8 test profile), not the
 * §8 target itself — see the comment on each assertion for why, and
 * `65` Prompt 11's landed notes for the full before/after numbers this was
 * calibrated against (including deliberately importing `recharts` into the
 * home page to confirm these thresholds actually catch a regression, then
 * reverting it).
 */
module.exports = {
  ci: {
    collect: {
      startServerCommand: "npm run start -- -p 4174",
      startServerReadyPattern: "Ready in",
      startServerReadyTimeout: 30_000,
      url: ["http://localhost:4174/hu"],
      // A single run on a shared GitHub Actions runner is noisy enough to
      // fail outright on a bad sample (seen: performance 0.55, LCP ~29.6s,
      // against a clean local `next build && next start` measuring 0.97 and
      // ~1.6s for the identical build) — 3 runs lets lhci assert against the
      // median instead of gambling on whichever run the runner was busiest
      // for.
      numberOfRuns: 3,
    },
    assert: {
      assertions: {
        // Performance: measured 93 today (mobile). §8's target is ≥ 95 —
        // not met, tied to the same >100 KB root-layout JS baseline
        // documented since Prompt 3 as root-layout-level work, not
        // something a CI script closes as a side effect. 85 leaves buffer
        // for run-to-run noise while easily catching a real regression —
        // importing `recharts` alone dropped this to 89.
        "categories:performance": ["error", { minScore: 0.85 }],
        // Accessibility: measured 100 today, after this prompt fixed two
        // real contrast failures Lighthouse surfaced (ChatMock.tsx's
        // timestamp opacity, SponsoredBand.tsx's ad-slot label color) —
        // §8's own ≥ 100 target, now genuinely met, asserted at the real
        // target rather than a softened one.
        "categories:accessibility": ["error", { minScore: 1 }],
        // SEO: measured 92 today, capped by one specific audit —
        // `canonical` — that fails only because this runs against
        // `localhost`, not the real `https://lifey.hu` `metadataBase`
        // every canonical/hreflang tag correctly points at (verified
        // directly in a browser in Prompt 9). Not excluded outright, since
        // that risks masking a real future SEO regression — thresholded
        // instead, just below today's score.
        "categories:seo": ["error", { minScore: 0.9 }],
        // LCP: measured ~3.16s today (mobile, throttled) — §8's target is
        // < 2.0s, not met for the same root-layout JS reason as
        // performance above. 4s leaves real regression-catching room
        // (recharts pushed this to 3.64s) without gating on work this
        // script isn't the place to do.
        "largest-contentful-paint": ["error", { maxNumericValue: 4000 }],
        // CLS: measured ~0.005 today — already comfortably under §8's own
        // 0.05 target, so asserted at the literal target, not a softened one.
        "cumulative-layout-shift": ["error", { maxNumericValue: 0.05 }],
      },
    },
    upload: {
      target: "filesystem",
      outputDir: "./.lighthouseci",
    },
  },
};
