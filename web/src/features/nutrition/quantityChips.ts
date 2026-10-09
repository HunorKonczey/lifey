import type { FoodServing } from "./types";

/** One quick-quantity chip of the add-food dialog: an amount, and the serving that names it when it has one. */
export interface QuantityChip {
  value: number;
  /** Set for a food's own serving ("1 glass"); the plain amounts ("100 g") have none. */
  serving?: string;
}

/**
 * The chips under the quantity field (W2.6; LIF-146). A recipe offers half, one and two servings of itself. A food offers its own
 * named servings first, in the owner's order, then "100 g" and the last used amount - leaving out any plain amount a serving
 * already covers, so "1 glass · 100 g" is not followed by a bare "100 g".
 */
export function quantityChips(opts: { recipe: boolean; servings?: readonly FoodServing[]; lastGrams?: number }): QuantityChip[] {
  if (opts.recipe) return [0.5, 1, 2].map((value) => ({ value }));
  const named: QuantityChip[] = (opts.servings ?? []).map((s) => ({ value: s.grams, serving: s.name }));
  const last = opts.lastGrams && Math.round(opts.lastGrams) !== 100 ? Math.round(opts.lastGrams) : null;
  const plain = [100, ...(last != null ? [last] : [])].filter((g) => !named.some((c) => c.value === g)).map((value) => ({ value }));
  return [...named, ...plain];
}
