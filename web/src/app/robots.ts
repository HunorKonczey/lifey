import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";

/**
 * Allows the marketing tree, disallows the authenticated app (65 §5.3).
 * The doc's own wording names four examples — "/dashboard, /admin,
 * /superadmin, /onboarding" — but its stated reason ("behind a login and
 * have no business in an index") applies identically to every other
 * `(app)`-group route (nutrition/workouts/statistics/steps/water/weight/
 * settings), so this disallows the full authenticated surface rather than
 * only the four named examples. `/login`, `/register` and
 * `/forgot-password` stay crawlable — they're public entry points, not
 * behind a login, and `/register` is also a marketing CTA target.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: [
        "/admin",
        "/admin/",
        "/superadmin",
        "/superadmin/",
        "/dashboard",
        "/onboarding",
        "/nutrition",
        "/workouts",
        "/statistics",
        "/steps",
        "/water",
        "/weight",
        "/settings",
      ],
    },
    sitemap: `${SITE_URL}/sitemap.xml`,
  };
}
