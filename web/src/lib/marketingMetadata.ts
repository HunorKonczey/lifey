import type { Metadata } from "next";
import { routing } from "@/i18n/routing";
import { getPathname } from "@/i18n/navigation";

type MarketingHref = Parameters<typeof getPathname>[0]["href"];

/**
 * One `generateMetadata` builder for every marketing page (docs/landing_page/
 * 65 §5.1) — canonical + hreflang alternates (`hu`/`en` plus `x-default` →
 * `hu`, per §5.1's own wording) and matching OpenGraph/Twitter cards, from
 * one call per page instead of eleven hand-rolled copies.
 *
 * `href` is the *canonical* pathname key from `routing.pathnames` (e.g.
 * `"/for-trainers"`), not the locale-specific slug — `getPathname` resolves
 * it per locale, the same way `Link` does.
 */
export function buildMetadata({
  locale,
  href,
  title,
  description,
}: {
  locale: string;
  href: MarketingHref;
  title: string;
  description: string;
}): Metadata {
  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, getPathname({ locale: l, href })])
  );

  return {
    title,
    description,
    alternates: {
      canonical: getPathname({ locale, href }),
      languages: { ...languages, "x-default": languages[routing.defaultLocale] },
    },
    openGraph: {
      title,
      description,
      url: getPathname({ locale, href }),
      siteName: "Lifey",
      locale: locale === "hu" ? "hu_HU" : "en_US",
      type: "website",
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
    },
  };
}
