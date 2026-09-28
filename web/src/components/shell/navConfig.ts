export interface NavItemDef {
  href: string;
  /** Key into the "nav" i18n namespace, and the fixture id in the shell gallery demo. */
  key: string;
  icon: string;
  /** The letter shown in the collapsed tooltip for the future `G <letter>`
   *  go-to shortcut (D-W0.17) — cosmetic only until W0.25 wires `useHotkeys`.
   *  D/N/W/S come straight from the plan; the rest are this step's own pick. */
  shortcut: string;
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
