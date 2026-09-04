import type { MetadataRoute } from "next";
import { routing } from "@/i18n/routing";
import { getPathname } from "@/i18n/navigation";
import { SITE_URL } from "@/lib/site";

/**
 * Lists every marketing route in both locales, each with `alternates.
 * languages` for the other locale (65 §5.3). `routing.pathnames`' keys are
 * the single source for what counts as a "marketing route" — adding a page
 * without adding it there already breaks locale routing (D-W4), so nothing
 * can end up in the sitemap without also being a real, working route.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const hrefs = Object.keys(routing.pathnames) as (keyof typeof routing.pathnames)[];

  return hrefs.flatMap((href) =>
    routing.locales.map((locale) => ({
      url: `${SITE_URL}${getPathname({ locale, href })}`,
      alternates: {
        languages: Object.fromEntries(
          routing.locales.map((l) => [l, `${SITE_URL}${getPathname({ locale: l, href })}`])
        ),
      },
    }))
  );
}
