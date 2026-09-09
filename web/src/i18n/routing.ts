import { defineRouting } from "next-intl/routing";

/**
 * Locale routing for the marketing tree only (docs/landing_page/65
 * §D-W3) — the authenticated app keeps resolving locale client-side
 * from `settings.language` via `useLocale`/`I18nProvider`, unrelated
 * to this config.
 *
 * Localized pathnames per docs/landing_page/65 §D-W4. Hungarian is the
 * default locale and sets the canonical route keys below; new marketing
 * routes must be added here before they're linked anywhere. Also add the
 * new HU path to `scripts/check-js-budget.mjs`'s `ROUTES` list (65 Prompt
 * 11) — that script can't import this file directly (it runs outside
 * Next's build pipeline, as a plain Node script against the built output),
 * so its route list is a hand-kept copy, not derived from this one.
 */
export const routing = defineRouting({
  locales: ["hu", "en"],
  defaultLocale: "hu",
  localePrefix: "always",
  pathnames: {
    "/": "/",
    "/for-trainers": { hu: "/edzoknek", en: "/for-trainers" },
    "/app": { hu: "/alkalmazas", en: "/app" },
    "/pricing": { hu: "/arak", en: "/pricing" },
    "/faq": { hu: "/gyik", en: "/faq" },
    "/download": { hu: "/letoltes", en: "/download" },
    "/contact": { hu: "/kapcsolat", en: "/contact" },
    "/legal/terms": { hu: "/jogi/aszf", en: "/legal/terms" },
    "/legal/privacy": { hu: "/jogi/adatkezeles", en: "/legal/privacy" },
    // Added beyond the original 65 §D-W4 table — the delivered footer
    // (design/Lifey Landing.dc.html, L02) links four legal pages, not two.
    // Both are real, separately required documents in Hungary/EU (a
    // standalone withdrawal-rights notice per Korm. rendelet 45/2014, and a
    // company-details "Impresszum" page), not design flourishes.
    "/legal/withdrawal": { hu: "/jogi/elallas", en: "/legal/withdrawal" },
    "/legal/imprint": { hu: "/jogi/impresszum", en: "/legal/imprint" },
  },
});
