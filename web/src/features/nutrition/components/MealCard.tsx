"use client";

import { useTranslations } from "next-intl";
import { Card, Icon, IconButton } from "@/components/ds";
import { RowMenuButton } from "@/components/ds/RowMenuButton";
import type { MenuItemDef } from "@/components/ds/Menu";
import { useFormat } from "@/lib/format/useFormat";
import { MEAL_TYPE_STYLE } from "../mealTypeStyle";
import type { MealResponse } from "../types";
import { MealItemRow, type MealItemRowData } from "./MealItemRow";

export function mealKcal(m: MealResponse) {
  return m.entries.reduce((s, e) => s + e.calories, 0);
}
export function mealProtein(m: MealResponse) {
  return m.entries.reduce((s, e) => s + e.protein, 0);
}
export function mealCarbs(m: MealResponse) {
  return m.entries.reduce((s, e) => s + e.carbs, 0);
}
export function mealFat(m: MealResponse) {
  return m.entries.reduce((s, e) => s + e.fat, 0);
}

/** A recipe logged as a meal carries the recipe's name (`LogRecipeDialog`); a meal built
 *  from foods has none — the card then lists its foods individually. */
export function isRecipeMeal(meal: MealResponse): boolean {
  return meal.name != null && meal.name.trim() !== "";
}

/** The rows a card shows: each food, or — for a recipe — one row for the whole portion. */
export function mealItemRows(meal: MealResponse): MealItemRowData[] {
  if (isRecipeMeal(meal)) {
    return [
      {
        name: meal.name!,
        grams: meal.entries.reduce((s, e) => s + e.quantityInGrams, 0),
        kcal: mealKcal(meal),
        protein: mealProtein(meal),
        carbs: mealCarbs(meal),
        fat: mealFat(meal),
      },
    ];
  }
  return meal.entries.map((e) => ({
    name: e.foodName,
    grams: e.quantityInGrams,
    kcal: e.calories,
    protein: e.protein,
    carbs: e.carbs,
    fat: e.fat,
  }));
}

interface MealCardProps {
  meal: MealResponse;
  /** "＋" in the header: add another food to this meal. */
  onAdd?: () => void;
  onEdit?: () => void;
  onDuplicate?: () => void;
  onDelete?: () => void;
  isDeleting?: boolean;
}

/**
 * One logged meal (W2.3, client-004): a 40 px tinted icon in the meal type's
 * colour, the type as the title, "07:15 · 3 tétel" (or "12:30 · recept") under
 * it, the kcal total, "＋" and a "⋯" (edit, copy, delete) in the header; the
 * foods below as `MealItemRow`s. Without any handler (the trainer's read-only
 * view of a client's day) the actions simply aren't drawn.
 */
export function MealCard({ meal, onAdd, onEdit, onDuplicate, onDelete, isDeleting }: MealCardProps) {
  const t = useTranslations("nutrition");
  const fmt = useFormat();
  const style = MEAL_TYPE_STYLE[meal.mealType];
  const recipe = isRecipeMeal(meal);
  const time = fmt.time(new Date(meal.dateTime));

  const menu: MenuItemDef[] = [
    ...(onEdit ? [{ label: t("menuEdit"), icon: "edit", onSelect: onEdit }] : []),
    ...(onDuplicate ? [{ label: t("menuDuplicate"), icon: "content_copy", onSelect: onDuplicate }] : []),
    ...(onDelete ? [{ label: t("menuDelete"), icon: "delete", destructive: true, onSelect: onDelete }] : []),
  ];
  const rowMenu: MenuItemDef[] = onEdit ? [{ label: t("menuEdit"), icon: "edit", onSelect: onEdit }] : [];

  return (
    <Card className="overflow-hidden" style={{ padding: 0 }} data-testid="meal-card" data-meal-type={meal.mealType}>
      <div className="flex items-center gap-4 px-4 py-3.5">
        <span
          className="flex shrink-0 items-center justify-center"
          style={{
            width: 40,
            height: 40,
            borderRadius: "var(--r-control)",
            background: `color-mix(in srgb, ${style.color} var(--chip-tint), transparent)`,
          }}
        >
          <Icon name={style.icon} size={22} fill={1} color={style.color} />
        </span>
        <div className="min-w-0 flex-1">
          <h3 style={{ fontSize: 16, fontWeight: 800 }}>{t(MEAL_TYPE_KEY[meal.mealType])}</h3>
          <p className="type-body-s tabular" style={{ color: "var(--text-3)" }}>
            {recipe ? t("recipeMealMeta", { time }) : t("mealMeta", { time, count: meal.entries.length })}
          </p>
        </div>
        <p className="tabular" style={{ fontSize: 17, fontWeight: 800 }}>
          {fmt.integer(mealKcal(meal))}{" "}
          <span className="type-body-s" style={{ color: "var(--text-3)", fontWeight: 600 }}>
            kcal
          </span>
        </p>
        {onAdd && <IconButton icon="add" label={t("addToThisMeal")} onClick={onAdd} disabled={isDeleting} />}
        {menu.length > 0 && <RowMenuButton items={menu} label={t("mealMenuLabel")} />}
      </div>

      <div>
        {mealItemRows(meal).map((item, i) => (
          <MealItemRow key={i} item={item} menu={rowMenu} />
        ))}
      </div>
    </Card>
  );
}

const MEAL_TYPE_KEY = {
  BREAKFAST: "breakfast",
  LUNCH: "lunch",
  SNACK: "snack",
  DINNER: "dinner",
} as const;
