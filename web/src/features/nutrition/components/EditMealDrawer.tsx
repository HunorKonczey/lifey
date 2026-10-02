"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, TintedChip } from "@/components/ds";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { NumberField } from "@/components/ds/field/NumberField";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import { mealApi } from "../api";
import { editedEntries, isMealDirty, round1 } from "../mealEdit";
import type { MealResponse } from "../types";

const MEAL_KEY = { BREAKFAST: "breakfast", LUNCH: "lunch", SNACK: "snack", DINNER: "dinner" } as const;

export interface EditMealDrawerViewProps {
  meal: MealResponse;
  onClose: () => void;
  onSave: (entries: { foodId: number; quantityInGrams: number }[]) => void;
  saving?: boolean;
}

/**
 * "Reggeli szerkesztése" (W2.7, extra-001): a right-hand `Drawer` with one row
 * per food — name, a quantity field (one decimal, the locale's comma: "166,7 g"
 * round-trips) and its kcal, which follows the quantity live. **Mentés** stays
 * disabled until something actually changed, the "Nem mentett változás" chip
 * appears with the first change, and Esc, the scrim and × ask before
 * discarding (the drawer's own guard). Rows the user never touched are saved
 * with their stored quantity, not a rounded copy of it.
 */
export function EditMealDrawerView({ meal, onClose, onSave, saving }: EditMealDrawerViewProps) {
  const t = useTranslations("nutrition");
  const common = useTranslations("common");
  const fmt = useFormat();
  // null = untouched (keeps the stored, unrounded quantity)
  const [edits, setEdits] = useState<(number | null)[]>(() => meal.entries.map(() => null));

  const dirty = isMealDirty(meal.entries, edits);
  const valid = edits.every((v) => v == null || v > 0);

  return (
    <Drawer
      open
      onClose={onClose}
      width={480}
      title={t("editMealTitle", { meal: t(MEAL_KEY[meal.mealType]) })}
      isDirty={dirty}
      badge={dirty ? <TintedChip label={t("unsavedChange")} color="var(--record)" size="small" /> : undefined}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {common("discardConfirm")}
          </Button>
          <Button onClick={() => onSave(editedEntries(meal.entries, edits))} disabled={!dirty || !valid || saving}>
            {saving ? common("saving") : common("save")}
          </Button>
        </>
      }
    >
      <ul className="flex flex-col" data-testid="edit-meal-rows">
        {meal.entries.map((e, i) => {
          const grams = edits[i] ?? round1(e.quantityInGrams);
          const kcal = e.quantityInGrams > 0 ? (e.calories * grams) / e.quantityInGrams : 0;
          return (
            <li
              key={i}
              className="grid items-center gap-3 py-3"
              style={{ gridTemplateColumns: "minmax(0,1fr) 140px 56px", borderTop: i === 0 ? undefined : "1px solid var(--hairline)" }}
            >
              <span style={{ fontSize: 15, fontWeight: 700, overflowWrap: "anywhere" }}>{e.foodName}</span>
              <NumberField
                value={grams}
                onChange={(v) => setEdits((prev) => prev.map((p, j) => (j === i ? v : p)))}
                unit="g"
                step={10}
                min={0.1}
                max={5000}
                maxDecimals={1}
                liveUpdate
                selectOnFocus
                size="dense"
                aria-label={e.foodName}
              />
              <span className="tabular text-right" style={{ fontSize: 15, fontWeight: 700 }}>
                {fmt.integer(kcal)}
              </span>
            </li>
          );
        })}
      </ul>
    </Drawer>
  );
}

/** The connected drawer: saves the edited quantities and refreshes the day. */
export function EditMealDrawer({ meal, onClose }: { meal: MealResponse; onClose: () => void }) {
  const t = useTranslations("nutrition");
  const queryClient = useQueryClient();
  const { show } = useToast();

  const save = useMutation({
    mutationFn: (entries: { foodId: number; quantityInGrams: number }[]) =>
      mealApi.update(meal.id, { dateTime: meal.dateTime, mealType: meal.mealType, name: meal.name, entries }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show(t("mealSaved"), "success");
      onClose();
    },
    onError: () => show(t("mealSaveFailed"), "error"),
  });

  return <EditMealDrawerView meal={meal} onClose={onClose} onSave={(entries) => save.mutate(entries)} saving={save.isPending} />;
}
