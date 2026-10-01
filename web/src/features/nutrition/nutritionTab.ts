export const NUTRITION_TABS = ["meals", "foods", "recipes"] as const;
export type NutritionTab = (typeof NUTRITION_TABS)[number];

/** The `?tab=` value as a tab — anything unknown or missing is the meals tab, so a stale
 *  or hand-edited link never lands on a blank page. */
export function parseNutritionTab(param: string | null | undefined): NutritionTab {
  return (NUTRITION_TABS as readonly string[]).includes(param ?? "") ? (param as NutritionTab) : "meals";
}

/** The href for a tab: meals is the default, so it carries no query at all. */
export function nutritionTabHref(tab: NutritionTab): string {
  return tab === "meals" ? "/nutrition" : `/nutrition?tab=${tab}`;
}
