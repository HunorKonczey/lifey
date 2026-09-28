/** D-W0.14's per-route chrome — currently just what W0.21 needs (a page
 *  title key and whether the date stepper shows); the centre-slot swap for
 *  statistics/weight and `focus` (no-chrome) mode are later W-steps' own
 *  additions to this same file, not yet built. */
export interface RouteChrome {
  /** Key into the "nav" i18n namespace, or `null` for no title (falls back to "Lifey"). */
  titleKey: string | null;
  /** Only pages with a "day" get the top-bar date stepper (D-W0.21). */
  hasDateStepper: boolean;
}

const TITLE_KEYS: Record<string, string> = {
  "/dashboard": "dashboard",
  "/nutrition": "nutrition",
  "/workouts": "workouts",
  "/weight": "weight",
  "/water": "water",
  "/steps": "steps",
  "/statistics": "statistics",
  "/settings": "settings",
};

// Trainer client detail pages ("/admin/clients/[id]") also get the stepper —
// listed by prefix like everything else here, per D-W0.21's own wording.
const DATED_PREFIXES = ["/dashboard", "/nutrition", "/water", "/steps", "/admin/clients"];

export function routeChrome(pathname: string): RouteChrome {
  const titleKey = Object.entries(TITLE_KEYS).find(([prefix]) => pathname.startsWith(prefix))?.[1] ?? null;
  const hasDateStepper = DATED_PREFIXES.some((prefix) => pathname.startsWith(prefix));
  return { titleKey, hasDateStepper };
}
