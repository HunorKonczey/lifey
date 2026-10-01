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
  /** `focus` (W3.6): no sidebar, top bar, bottom nav or global shortcuts — the page owns the whole window
   *  (the live workout logger, and the onboarding wizard, W6.5). `standard` is everything else. */
  chrome: "standard" | "focus";
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
  // Superadmin shell (D-W0.24) — same "superadmin" keys as its own page headings.
  "/superadmin/users": "superadmin.usersTitle",
  "/superadmin/trainer-requests": "superadmin.trainerRequestsTitle",
  "/superadmin/role-history": "superadmin.roleHistoryTitle",
};

// Trainer client detail pages ("/admin/clients/[id]") also get the stepper —
// listed by prefix like everything else here, per D-W0.21's own wording.
// Routes that take over the window. "/workouts/session/" — with the slash — so "/workouts" itself stays standard.
const FOCUS_PREFIXES = ["/workouts/session/", "/onboarding"];

const DATED_PREFIXES = ["/dashboard", "/nutrition", "/water", "/steps", "/admin/clients"];

export function routeChrome(pathname: string): RouteChrome {
  // Longest-prefix match first — "/admin" would otherwise shadow "/admin/billing".
  const titleKey =
    Object.entries(TITLE_KEYS)
      .filter(([prefix]) => pathname.startsWith(prefix))
      .sort((a, b) => b[0].length - a[0].length)[0]?.[1] ?? null;
  const hasDateStepper = DATED_PREFIXES.some((prefix) => pathname.startsWith(prefix));
  const chrome = FOCUS_PREFIXES.some((prefix) => pathname.startsWith(prefix)) ? "focus" : "standard";
  return { titleKey, hasDateStepper, chrome };
}
