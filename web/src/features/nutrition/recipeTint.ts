import type { Macros } from "./recipeMacros";

export type DominantMacro = "protein" | "carbs" | "fat";

/** Atwater factors: kcal per gram. */
const KCAL_PER_GRAM: Record<DominantMacro, number> = { protein: 4, carbs: 4, fat: 9 };

/**
 * The macro that supplies the largest share of a recipe's kcal (W2.11): protein and carbs at 4 kcal/g,
 * fat at 9. On a tie protein wins over carbs over fat; a recipe with no macro data has no dominant one (null).
 */
export function dominantMacro({ protein, carbs, fat }: Pick<Macros, DominantMacro>): DominantMacro | null {
  const shares: [DominantMacro, number][] = [
    ["protein", protein * KCAL_PER_GRAM.protein],
    ["carbs", carbs * KCAL_PER_GRAM.carbs],
    ["fat", fat * KCAL_PER_GRAM.fat],
  ];
  let best: [DominantMacro, number] | null = null;
  for (const s of shares) if (s[1] > 0 && (best === null || s[1] > best[1])) best = s;
  return best ? best[0] : null;
}

/** The recipe card's icon holder (shown when the recipe has no photo): the dominant macro's metric colour and an icon for it. */
export const RECIPE_TINT: Record<DominantMacro | "none", { macro: DominantMacro | "none"; color: string; icon: string }> = {
  protein: { macro: "protein", color: "var(--metric-protein)", icon: "egg_alt" },
  carbs: { macro: "carbs", color: "var(--metric-carbs)", icon: "bakery_dining" },
  fat: { macro: "fat", color: "var(--metric-fat)", icon: "water_drop" },
  none: { macro: "none", color: "var(--primary)", icon: "menu_book" },
};

export function recipeTint(macros: Pick<Macros, DominantMacro>) {
  return RECIPE_TINT[dominantMacro(macros) ?? "none"];
}
