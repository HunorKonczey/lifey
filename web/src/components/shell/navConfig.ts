export interface NavItemDef {
  href: string;
  /** Key into `namespace` (default "nav"). */
  key: string;
  icon: string;
  /** The letter shown in the collapsed tooltip for the future `G <letter>`
   *  go-to shortcut (D-W0.17) — cosmetic only until W0.25 wires `useHotkeys`.
   *  D/N/W/S come straight from the plan; the rest are this step's own pick. */
  shortcut: string;
  /** i18n namespace `key` resolves in — "nav" (client) unless overridden. */
  namespace?: string;
}

/** DS-02's client nav (D-W0.20): Áttekintő · Táplálkozás · Edzések · Testsúly · Víz · Lépések · Statisztika. */
export const CLIENT_NAV_ITEMS: NavItemDef[] = [
  { href: "/dashboard", key: "dashboard", icon: "space_dashboard", shortcut: "D" },
  { href: "/nutrition", key: "nutrition", icon: "restaurant", shortcut: "N" },
  { href: "/workouts", key: "workouts", icon: "fitness_center", shortcut: "W" },
  { href: "/weight", key: "weight", icon: "monitor_weight", shortcut: "E" },
  { href: "/water", key: "water", icon: "water_drop", shortcut: "A" },
  { href: "/steps", key: "steps", icon: "directions_walk", shortcut: "P" },
  { href: "/statistics", key: "statistics", icon: "bar_chart", shortcut: "S" },
];

export const SETTINGS_NAV_ITEM: NavItemDef = {
  href: "/settings",
  key: "settings",
  icon: "settings",
  shortcut: "C",
};

/** Bottom nav (D-W0.22): the client's first four + a "Több" sheet for the rest + Settings. */
export const CLIENT_BOTTOM_NAV_ITEMS = CLIENT_NAV_ITEMS.slice(0, 4);
export const CLIENT_MORE_SHEET_ITEMS = [...CLIENT_NAV_ITEMS.slice(4), SETTINGS_NAV_ITEM];

/**
 * Trainer nav (D-W0.22/W0.23) — reuses `AdminSidebar.tsx`'s existing routes,
 * icons and `admin.nav` i18n keys (unchanged this step) rather than
 * inventing new ones. It's a stand-in shape for this step's mobile
 * bottom-nav gallery demo only: the plan's DS-02 four-item trainer row
 * ("Klienseim · Naptár · Chat · Tervek") names a "Tervek" grouping that
 * doesn't exist as a single route yet — that regrouping is W0.23's own
 * "TARTALOM" redesign, not this one, so this picks four of today's nine
 * real admin nav items instead. The real trainer `AppShell` wiring is
 * W0.23, not this step.
 */
export const TRAINER_NAV_ITEMS: NavItemDef[] = [
  { href: "/admin", key: "clients", icon: "group", shortcut: "K", namespace: "admin.nav" },
  { href: "/admin/calendar", key: "calendar", icon: "calendar_month", shortcut: "N", namespace: "admin.nav" },
  { href: "/admin/chat", key: "chat", icon: "chat_bubble", shortcut: "H", namespace: "admin.nav" },
  { href: "/admin/programs", key: "programs", icon: "event_repeat", shortcut: "V", namespace: "admin.nav" },
];
export const TRAINER_MORE_SHEET_ITEMS: NavItemDef[] = [
  { href: "/admin/nutrition", key: "nutrition", icon: "restaurant", shortcut: "M", namespace: "admin.nav" },
  { href: "/admin/workouts", key: "workouts", icon: "fitness_center", shortcut: "F", namespace: "admin.nav" },
  { href: "/admin/assignments", key: "assignments", icon: "assignment", shortcut: "J", namespace: "admin.nav" },
  { href: "/admin/invites", key: "invites", icon: "mail", shortcut: "I", namespace: "admin.nav" },
  { href: "/admin/billing", key: "billing", icon: "credit_card", shortcut: "B", namespace: "admin.nav" },
];
