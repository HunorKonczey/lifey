"use client";

import { useTranslations } from "next-intl";
import { Button, Card, Icon } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { MEAL_TYPE_STYLE } from "../mealTypeStyle";
import type { MealType } from "../types";

const KEY = { BREAKFAST: "breakfast", LUNCH: "lunch", SNACK: "snack", DINNER: "dinner" } as const;

export interface EmptyMealSlotProps {
  mealType: MealType;
  /** What still fits in the day's budget; null without a calorie goal (or once it's used up). */
  remainingKcal: number | null;
  /** Yesterday's meals of this type, when there are some to copy. */
  copyOffer?: { kcal: number; pending?: boolean; onCopy: () => void } | null;
  onAdd: () => void;
}

/**
 * A meal type with nothing logged yet (W2.4, client-004): a quiet nested card
 * — the type's icon, its name, "Még nincs naplózva · 859 kcal fér bele" — with
 * a one-click "Tegnapi vacsora · 612 kcal" chip when yesterday had one, and
 * "＋ Hozzáadás". Replaces the old dashed buttons.
 */
export function EmptyMealSlot({ mealType, remainingKcal, copyOffer, onAdd }: EmptyMealSlotProps) {
  const t = useTranslations("nutrition");
  const fmt = useFormat();
  const style = MEAL_TYPE_STYLE[mealType];
  const name = t(KEY[mealType]);
  const meal = name.toLocaleLowerCase(fmt.locale);

  return (
    <Card variant="nested" className="flex flex-wrap items-center gap-x-4 gap-y-3" style={{ padding: "14px 16px" }} data-testid="empty-slot" data-meal-type={mealType}>
      <span
        className="flex shrink-0 items-center justify-center"
        style={{ width: 40, height: 40, borderRadius: "var(--r-control)", background: "var(--control)" }}
      >
        <Icon name={style.icon} size={22} fill={1} color={style.color} />
      </span>
      <div className="min-w-0 flex-1" style={{ minWidth: 180 }}>
        <h3 style={{ fontSize: 16, fontWeight: 800 }}>{name}</h3>
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>
          {t("slotEmpty")}
          {remainingKcal != null && remainingKcal > 0 && <> · {t("slotBudget", { kcal: fmt.integer(remainingKcal) })}</>}
        </p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        {copyOffer && (
          <Button variant="secondary" onClick={copyOffer.onCopy} disabled={copyOffer.pending} className="md:h-9!">
            <Icon name="content_copy" size={18} />
            {t("slotCopy", { meal, kcal: fmt.integer(copyOffer.kcal) })}
          </Button>
        )}
        <Button variant="tonal" onClick={onAdd} className="md:h-9!">
          <Icon name="add" size={18} />
          {t("slotAdd")}
        </Button>
      </div>
    </Card>
  );
}
