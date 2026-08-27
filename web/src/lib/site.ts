/**
 * The production origin — single source for every absolute URL the
 * marketing tree needs (canonical/hreflang links, JSON-LD `url` fields,
 * `sitemap.ts`/`robots.ts`). Introduced in Prompt 9 (docs/landing_page/65
 * §5); Prompts 6 and 8 each hand-typed `"https://lifey.hu"` once for their
 * own JSON-LD — both now import this instead.
 */
export const SITE_URL = "https://lifey.hu";
