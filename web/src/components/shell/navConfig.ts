import type { SessionUser } from "@/features/auth/types";

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

/** A labelled section of the desktop `Sidebar` (D-W0.23) — `label` is a full
 *  dotted i18n key (e.g. "admin.nav.groupClients"), resolved the same way
 *  `BottomNav`/`MoreSheet` resolve `NavItemDef.key` (a namespace-less
 *  `useTranslations()` and one dotted path), not `NavItemDef`'s own
 *  key+namespace pair — a group's label lives in a different key shape than
 *  its items ("groupClients" vs "clients") so reusing that pair doesn't fit. */
export interface NavGroup {
  label?: string;
  items: NavItemDef[];
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

/** Preserved from the pre-DS-02 client sidebar, not itself in the DS-02
 *  canvas: a dual-role user's quick jump into their other area. */
const TRAINER_VIEW_ITEM: NavItemDef = { href: "/admin", key: "trainerView", icon: "storefront", shortcut: "T" };
const SYSTEM_VIEW_ITEM: NavItemDef = { href: "/superadmin/users", key: "systemView", icon: "admin_panel_settings", shortcut: "Y" };

/** The client's nav groups, with role-gated jump links appended for a
 *  trainer/superadmin who's currently in their client view. */
export function clientGroupsFor(user: Pick<SessionUser, "roles">): NavGroup[] {
  const extra: NavItemDef[] = [];
  if (user.roles.includes("ROLE_TRAINER")) extra.push(TRAINER_VIEW_ITEM);
  if (user.roles.includes("ROLE_SUPER_ADMIN")) extra.push(SYSTEM_VIEW_ITEM);
  return extra.length > 0 ? [{ items: CLIENT_NAV_ITEMS }, { items: extra }] : [{ items: CLIENT_NAV_ITEMS }];
}

export const CLIENT_NAV_GROUPS: NavGroup[] = [{ items: CLIENT_NAV_ITEMS }];

/** Bottom nav (D-W0.22): the client's first four + a "Több" sheet for the rest + Settings. */
export const CLIENT_BOTTOM_NAV_ITEMS = CLIENT_NAV_ITEMS.slice(0, 4);
export const CLIENT_MORE_SHEET_ITEMS = [...CLIENT_NAV_ITEMS.slice(4), SETTINGS_NAV_ITEM];

const CLIENTS_GROUP: NavItemDef[] = [
  { href: "/admin", key: "clients", icon: "group", shortcut: "K", namespace: "admin.nav" },
  { href: "/admin/calendar", key: "calendar", icon: "calendar_month", shortcut: "N", namespace: "admin.nav" },
  { href: "/admin/chat", key: "chat", icon: "chat_bubble", shortcut: "H", namespace: "admin.nav" },
  { href: "/admin/invites", key: "invites", icon: "mail", shortcut: "I", namespace: "admin.nav" },
];
const CONTENT_GROUP: NavItemDef[] = [
  { href: "/admin/workouts", key: "workouts", icon: "fitness_center", shortcut: "F", namespace: "admin.nav" },
  { href: "/admin/programs", key: "programs", icon: "event_repeat", shortcut: "V", namespace: "admin.nav" },
  { href: "/admin/nutrition", key: "nutrition", icon: "restaurant", shortcut: "M", namespace: "admin.nav" },
  { href: "/admin/assignments", key: "assignments", icon: "assignment", shortcut: "J", namespace: "admin.nav" },
];
const ACCOUNT_GROUP: NavItemDef[] = [
  { href: "/admin/billing", key: "billing", icon: "credit_card", shortcut: "B", namespace: "admin.nav" },
  { href: "/dashboard", key: "backToOwnView", icon: "undo", shortcut: "O", namespace: "admin.nav" },
];

/**
 * Trainer nav (D-W0.23): DS-02's "EDZŐ · csoportosítva" — KLIENSEK, TARTALOM,
 * FIÓK — reusing `AdminSidebar.tsx`'s existing nine routes/icons/`admin.nav`
 * i18n keys rather than inventing new ones. Group labels resolve from
 * "admin.nav.groups" (added this step).
 */
export const TRAINER_NAV_GROUPS: NavGroup[] = [
  { label: "admin.nav.groupClients", items: CLIENTS_GROUP },
  { label: "admin.nav.groupContent", items: CONTENT_GROUP },
  { label: "admin.nav.groupAccount", items: ACCOUNT_GROUP },
];

/**
 * The mobile bottom nav only has room for four + "Több" (D-W0.22) — a flat
 * pick across the three groups above, not a literal "Tervek" aggregate
 * route (DS-02 names one; it doesn't exist yet, see W0.22's As-built).
 */
export const TRAINER_NAV_ITEMS: NavItemDef[] = [CLIENTS_GROUP[0], CLIENTS_GROUP[1], CLIENTS_GROUP[2], CONTENT_GROUP[1]];
export const TRAINER_MORE_SHEET_ITEMS: NavItemDef[] = [
  CONTENT_GROUP[2],
  CONTENT_GROUP[0],
  CONTENT_GROUP[3],
  CLIENTS_GROUP[3],
  ACCOUNT_GROUP[0],
  ACCOUNT_GROUP[1],
];
