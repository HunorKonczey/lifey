export const WORKOUTS_TABS = ["sessions", "templates", "exercises"] as const;
export type WorkoutsTab = (typeof WORKOUTS_TABS)[number];

/** The `?tab=` value as a tab — anything unknown or missing is the sessions tab, so a stale
 *  or hand-edited link never lands on a blank page. */
export function parseWorkoutsTab(param: string | null | undefined): WorkoutsTab {
  return (WORKOUTS_TABS as readonly string[]).includes(param ?? "") ? (param as WorkoutsTab) : "sessions";
}

/** The href for a tab: sessions is the default, so it carries no query at all. */
export function workoutsTabHref(tab: WorkoutsTab): string {
  return tab === "sessions" ? "/workouts" : `/workouts?tab=${tab}`;
}

export const SESSION_TYPE_FILTERS = ["all", "strength", "cardio"] as const;
export type SessionTypeFilter = (typeof SESSION_TYPE_FILTERS)[number];

/** Whether a session of this kind shows under the filter (W3-A chips Mind · Erősítő · Cardio). */
export function matchesTypeFilter(sessionKind: string | null | undefined, filter: SessionTypeFilter): boolean {
  if (filter === "all") return true;
  return filter === "cardio" ? sessionKind === "CARDIO" : sessionKind !== "CARDIO";
}
