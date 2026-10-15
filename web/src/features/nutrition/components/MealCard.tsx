"use client";

import type { ReactNode } from "react";
import { useTranslations } from "next-intl";
import { Card, Icon, IconButton } from "@/components/ds";
import { RowMenuButton } from "@/components/ds/RowMenuButton";
import type { MenuItemDef } from "@/components/ds/Menu";
import { useFormat } from "@/lib/format/useFormat";
import { fiberSugarOfEntries } from "../fiberSugar";
import { MEAL_TYPE_STYLE } from "../mealTypeStyle";
import type { MealResponse } from "../types";
import { FiberSugarLine } from "./FiberSugarLine";
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

/**
 * The recipe a meal is nothing but, or null (docs/88): a meal whose entries all carry the same recipe id - however the
 * meal got there, named or not - or, for meals logged before the tags existed, a named meal none of whose entries are
 * tagged (a recipe logged as a meal of its own carries the recipe name). A recipe mixed into a meal with other foods is
 * not one: the card groups its entries instead (`mealItemRows`).
 */
export function recipeMealName(meal: MealResponse): string | null {
  const tags = meal.entries.map((e) => e.recipeId);
  if (tags.length > 0 && tags[0] != null && tags.every((id) => id === tags[0])) {
    return meal.entries[0].recipeName ?? (meal.name?.trim() ? meal.name : meal.entries[0].foodName);
  }
  const named = meal.name != null && meal.name.trim() !== "";
  return named && tags.every((id) => id == null) ? meal.name : null;
}

export function isRecipeMeal(meal: MealResponse): boolean {
  return recipeMealName(meal) != null;
}

/** One row of a meal card: a food, or all the entries of one recipe added to the meal (docs/88 §2.8). */
export interface MealRowData extends MealItemRowData {
  /** Indexes into `meal.entries` that the row stands for - one for a food, several for a recipe. */
  entryIndexes: number[];
}

/**
 * The rows a card shows: each loose food on its own, and the entries that share a recipe id as **one** row named after
 * the recipe, with the sum of their grams and macros, at the position of the group's first entry. A meal named after its
 * recipe whose entries carry no tag (logged before the tags existed) is one row for the whole portion.
 */
export function mealItemRows(meal: MealResponse): MealRowData[] {
  const recipeName = recipeMealName(meal);
  if (recipeName != null) {
    return [
      {
        name: recipeName,
        grams: meal.entries.reduce((s, e) => s + e.quantityInGrams, 0),
        kcal: mealKcal(meal),
        protein: mealProtein(meal),
        carbs: mealCarbs(meal),
        fat: mealFat(meal),
        entryIndexes: meal.entries.map((_, i) => i),
      },
    ];
  }
  const rows: MealRowData[] = [];
  const groupAt = new Map<number, MealRowData>();
  meal.entries.forEach((e, i) => {
    const group = e.recipeId != null ? groupAt.get(e.recipeId) : undefined;
    if (group) {
      group.grams += e.quantityInGrams;
      group.kcal += e.calories;
      group.protein += e.protein;
      group.carbs += e.carbs;
      group.fat += e.fat;
      group.entryIndexes.push(i);
      return;
    }
    const row: MealRowData = {
      name: e.recipeId != null ? (e.recipeName ?? e.foodName) : e.foodName,
      grams: e.quantityInGrams,
      kcal: e.calories,
      protein: e.protein,
      carbs: e.carbs,
      fat: e.fat,
      entryIndexes: [i],
    };
    rows.push(row);
    if (e.recipeId != null) groupAt.set(e.recipeId, row);
  });
  return rows;
}

interface MealCardProps {
  meal: MealResponse;
  /** "＋" in the header: add another food to this meal. */
  onAdd?: () => void;
  onEdit?: () => void;
  onDuplicate?: () => void;
  onDelete?: () => void;
  /** Delete one food (index into `meal.entries`); the parent asks first, and the last food takes the meal with it. */
  onDeleteItem?: (index: number) => void;
  /** Delete all the entries of one recipe from the meal (indexes into `meal.entries`); the parent asks first. */
  onDeleteGroup?: (indexes: number[], recipeName: string) => void;
  /**
   * Replaces the built-in, read-only block for the trainer's comment — the trainer's own view passes the editor here
   * (LIF-144). Without it a comment the trainer wrote is shown as plain text.
   */
  commentSlot?: ReactNode;
}

/**
 * One logged meal (W2.3, client-004): a 40 px tinted icon in the meal type's
 * colour, the type as the title, "07:15 · 3 tétel" (or "12:30 · recept") under
 * it, the kcal total, "＋" and a "⋯" (edit, copy, delete) in the header; the
 * foods below as `MealItemRow`s, then the trainer's comment when there is one. Without any handler (the trainer's
 * read-only view of a client's day) the actions simply aren't drawn.
 */
export function MealCard({ meal, onAdd, onEdit, onDuplicate, onDelete, onDeleteItem, onDeleteGroup, commentSlot }: MealCardProps) {
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
  const rows = mealItemRows(meal);
  // A row "⋯" deletes what the row stands for: a recipe card that is all one recipe deletes the meal, a recipe among
  // other foods deletes its entries, a food deletes just that food.
  const rowDelete = (row: MealRowData): (() => void) | undefined => {
    if (recipe || (row.entryIndexes.length > 1 && row.entryIndexes.length === meal.entries.length)) return onDelete;
    if (row.entryIndexes.length > 1) return onDeleteGroup ? () => onDeleteGroup(row.entryIndexes, row.name) : undefined;
    return onDeleteItem ? () => onDeleteItem(row.entryIndexes[0]) : undefined;
  };
  const rowMenu = (row: MealRowData): MenuItemDef[] => {
    const remove = rowDelete(row);
    return [
      ...(onEdit ? [{ label: t("menuEdit"), icon: "edit", onSelect: onEdit }] : []),
      ...(remove ? [{ label: t("menuDelete"), icon: "delete", destructive: true, onSelect: remove }] : []),
    ];
  };

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
        {onAdd && <IconButton icon="add" label={t("addToThisMeal")} onClick={onAdd} />}
        {menu.length > 0 && <RowMenuButton items={menu} label={t("mealMenuLabel")} />}
      </div>

      <div>
        {rows.map((item, i) => (
          <MealItemRow key={i} item={item} menu={rowMenu(item)} />
        ))}
      </div>

      <FiberSugarLine totals={fiberSugarOfEntries(meal.entries)} testId="meal-fiber-sugar" className="px-4 pb-3 pt-1" />

      {commentSlot ?? (meal.trainerComment ? <TrainerCommentBlock comment={meal.trainerComment} at={meal.trainerCommentAt ?? null} /> : null)}
    </Card>
  );
}

const MEAL_TYPE_KEY = {
  BREAKFAST: "breakfast",
  LUNCH: "lunch",
  SNACK: "snack",
  DINNER: "dinner",
} as const;

/** The trainer's comment on a meal, as the user sees it under the foods (LIF-144). */
function TrainerCommentBlock({ comment, at }: { comment: string; at: string | null }) {
  const t = useTranslations("nutrition");
  const fmt = useFormat();
  return (
    <div
      data-testid="meal-trainer-comment"
      className="mx-4 mb-4 mt-1 flex items-start gap-3 p-3"
      style={{ borderRadius: "var(--r-control)", background: "color-mix(in srgb, var(--role) 14%, transparent)" }}
    >
      <Icon name="chat_bubble" size={20} fill={1} color="var(--role)" />
      <div className="min-w-0 flex-1">
        <p className="type-label" style={{ color: "var(--text-2)" }}>{t("trainerComment")}</p>
        <p className="type-body" style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{comment}</p>
        {at && <p className="type-body-s" style={{ color: "var(--text-3)" }}>{fmt.shortDate(new Date(at))}</p>}
      </div>
    </div>
  );
}
