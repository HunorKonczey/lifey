"use client";

import { useTranslations } from "next-intl";
import { format } from "date-fns";
import type { MealResponse } from "../types";

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

interface MealCardProps {
  meal: MealResponse;
  onEdit?: () => void;
  onDuplicate?: () => void;
  onDelete?: () => void;
  isDeleting?: boolean;
}

export function MealCard({ meal, onEdit, onDuplicate, onDelete, isDeleting }: MealCardProps) {
  const t = useTranslations("nutrition");
  const readOnly = !onEdit && !onDelete;
  const kcal = Math.round(mealKcal(meal));
  const protein = Math.round(mealProtein(meal));
  const carbs = Math.round(mealCarbs(meal));
  const fat = Math.round(mealFat(meal));
  const time = format(new Date(meal.dateTime), "HH:mm");
  const title = meal.name ?? (meal.entries.length === 1 ? meal.entries[0].foodName : t("meals"));

  return (
    <div
      className="rounded-[var(--r-card)] p-4 group"
      style={{ background: "var(--surface)" }}
    >
      {/* Card header */}
      <div className="flex items-start justify-between gap-2 mb-3">
        <div className="flex-1 min-w-0">
          <p className="font-bold text-sm truncate">{title}</p>
          <p className="text-xs tabular mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
            {time} · {kcal} kcal · {protein}g P
            {readOnly && <> · {carbs}g C · {fat}g F</>}
          </p>
        </div>
        {!readOnly && (
          <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
            {onEdit && (
              <button
                onClick={onEdit}
                className="p-1 rounded-[var(--r-sm)] hover:bg-surface-container"
                style={{ color: "var(--muted)" }}
                aria-label={t("editMealAria")}
              >
                <span className="material-symbols-rounded text-lg">edit</span>
              </button>
            )}
            {onDuplicate && (
              <button
                onClick={onDuplicate}
                className="p-1 rounded-[var(--r-sm)] hover:bg-surface-container"
                style={{ color: "var(--muted)" }}
                aria-label={t("duplicateMealAria")}
              >
                <span className="material-symbols-rounded text-lg">content_copy</span>
              </button>
            )}
            {onDelete && (
              <button
                onClick={onDelete}
                disabled={isDeleting}
                className="p-1 rounded-[var(--r-sm)] hover:bg-surface-container disabled:opacity-30"
                style={{ color: "var(--muted)" }}
                aria-label={t("removeMealAria")}
              >
                <span className="material-symbols-rounded text-lg">delete</span>
              </button>
            )}
          </div>
        )}
      </div>

      {/* Ingredient rows */}
      <div className="flex flex-col">
        {meal.entries.map((e, i) => (
          <div
            key={i}
            className="flex items-center justify-between py-1.5"
            style={{ borderTop: "1px solid var(--outline)" }}
          >
            <span className="text-sm" style={{ color: "var(--on-surface-variant)" }}>
              {e.foodName}
            </span>
            <span className="text-xs tabular ml-4 shrink-0" style={{ color: "var(--muted)" }}>
              {Math.round(e.quantityInGrams)}g · {Math.round(e.calories)} kcal · {Math.round(e.protein)}g P
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
