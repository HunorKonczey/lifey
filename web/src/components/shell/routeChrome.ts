/** D-W0.14's per-route chrome — currently just what W0.21/23 need (a page
 *  title key and whether the date stepper shows); the centre-slot swap for
 *  statistics/weight and `focus` (no-chrome) mode are later W-steps' own
 *  additions to this same file, not yet built. */
export interface RouteChrome {
  /** A full dotted i18n key (e.g. "nav.dashboard", "admin.nav.clients"),
   *  resolved the same namespace-less way as `NavItemDef` elsewhere in
   *  `components/shell` — or `null` for no title (falls back to "Lifey"). */
  titleKey: string | null;
  /** Only pages with a "day" get the top-bar date stepper (D-W0.21). */
  hasDateStepper: boolean;
}

const TITLE_KEYS: Record<string, string> = {
  "/dashboard": "nav.dashboard",
  "/nutrition": "nav.nutrition",
  "/workouts": "nav.workouts",
  "/weight": "nav.weight",
  "/water": "nav.water",
  "/steps": "nav.steps",
  "/statistics": "nav.statistics",
  "/settings": "nav.settings",
  // Trainer shell (D-W0.23) — same `admin.nav` keys as `AdminSidebar`'s own nav.
  "/admin/calendar": "admin.nav.calendar",
  "/admin/chat": "admin.nav.chat",
  "/admin/invites": "admin.nav.invites",
  "/admin/billing": "admin.nav.billing",
  "/admin/workouts": "admin.nav.workouts",
  "/admin/programs": "admin.nav.programs",
  "/admin/nutrition": "admin.nav.nutrition",
  "/admin/assignments": "admin.nav.assignments",
  "/admin": "admin.nav.clients",
};

// Trainer client detail pages ("/admin/clients/[id]") also get the stepper —
// listed by prefix like everything else here, per D-W0.21's own wording.
const DATED_PREFIXES = ["/dashboard", "/nutrition", "/water", "/steps", "/admin/clients"];

export function routeChrome(pathname: string): RouteChrome {
  // Longest-prefix match first — "/admin" would otherwise shadow "/admin/billing".
  const titleKey =
    Object.entries(TITLE_KEYS)
      .filter(([prefix]) => pathname.startsWith(prefix))
      .sort((a, b) => b[0].length - a[0].length)[0]?.[1] ?? null;
  const hasDateStepper = DATED_PREFIXES.some((prefix) => pathname.startsWith(prefix));
  return { titleKey, hasDateStepper };
}
