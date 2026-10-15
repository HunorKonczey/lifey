"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { IconButton, NumberField } from "@/components/ds";
import { gramsFor, type GramsOverrides } from "../logRecipePortion";
import type { RecipeIngredientResponse } from "../types";

export interface IngredientAmountsProps {
  ingredients: RecipeIngredientResponse[];
  /** What the recipe is divided by for the portion being logged (1 = all of it). */
  divisor: number;
  /** The amounts typed by hand, by ingredient index; the others show the divisor-derived default. */
  overrides: GramsOverrides;
  onChange: (overrides: GramsOverrides) => void;
}

/**
 * "Adjust ingredients" (W2.11, docs/87 §2.3): behind a collapsed button, each ingredient's grams for the portion being
 * logged can be replaced with what was actually eaten — 0 leaves it out, a reset button restores the computed amount, and
 * a typed amount survives a change of the divisor. Shared by the Recipes tab's log dialog and the Add food dialog's
 * recipe preview.
 */
export function IngredientAmounts({ ingredients, divisor, overrides, onChange }: IngredientAmountsProps) {
  const t = useTranslations("nutrition.logRecipeDialog");
  const [show, setShow] = useState(false);

  if (ingredients.length === 0) return null;

  const reset = (index: number) => {
    const next = { ...overrides };
    delete next[index];
    onChange(next);
  };

  return (
    <div className="flex flex-col gap-2">
      <button
        type="button"
        aria-expanded={show}
        onClick={() => setShow((s) => !s)}
        className="lifey-button type-body-s inline-flex items-center gap-1.5 self-start"
        style={{ fontWeight: 700, color: "var(--text-2)", borderRadius: "var(--r-control)" }}
      >
        <span className="material-symbols-rounded" style={{ fontSize: 18 }} aria-hidden>
          {show ? "expand_less" : "tune"}
        </span>
        {t("adjustIngredients")}
      </button>
      {show && (
        <>
          <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("amountsHint")}</p>
          {ingredients.map((ing, i) => (
            <div
              key={i}
              className="flex items-center gap-2 px-3 py-2"
              style={{ background: "var(--nested)", borderRadius: "var(--r-control)" }}
              data-testid="log-ingredient"
            >
              <span className="type-body-s min-w-0 flex-1 truncate">{ing.foodName}</span>
              {overrides[i] !== undefined && <IconButton icon="restart_alt" label={t("resetAmount")} onClick={() => reset(i)} />}
              <NumberField
                aria-label={ing.foodName}
                size="dense"
                className="w-36"
                unit="g"
                value={gramsFor(ing, i, divisor, overrides)}
                onChange={(v) => onChange({ ...overrides, [i]: String(v) })}
                min={0}
                step={5}
                maxDecimals={2}
                selectOnFocus
              />
            </div>
          ))}
        </>
      )}
    </div>
  );
}
