import { createNavigation } from "next-intl/navigation";
import { routing } from "./routing";

/**
 * Locale-aware `Link`/`redirect`/etc. for the marketing tree, resolving
 * routes through the localized `pathnames` in `./routing.ts`. Marketing
 * pages must use this `Link`, never a raw `next/link`, or a Hungarian
 * page can end up linking to an English path by accident
 * (docs/landing_page/65 §3.2).
 */
export const { Link, redirect, permanentRedirect, usePathname, useRouter, getPathname } =
  createNavigation(routing);
