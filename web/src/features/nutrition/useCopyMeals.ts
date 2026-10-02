"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { mealApi } from "./api";
import { copyMealPayload } from "./copyMeal";
import type { MealResponse } from "./types";

export interface CopyMealsRequest {
  meals: MealResponse[];
  /** The success toast's text, already translated ("Copied yesterday's dinner"). */
  message: string;
}

/**
 * Copies meals onto `date` — never over anything, each becomes a new meal at
 * its original time of day — and offers **Undo** in the toast: Undo deletes
 * exactly the meals this copy created (W2.4 / W2.9). Shared by the empty-slot
 * "yesterday's dinner" chip and the copy-from-day popover.
 *
 * The undo is the opposite direction of `useUndoableDelete` (the items
 * already exist there, and their DELETE is what's deferred), so this calls the
 * toast store's `showUndo` directly, like the dashboard's copy button.
 */
export function useCopyMeals(date: Date) {
  const t = useTranslations("nutrition");
  const queryClient = useQueryClient();
  const invalidate = () => queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });

  return useMutation({
    mutationFn: async ({ meals }: CopyMealsRequest) => Promise.all(meals.map((m) => mealApi.create(copyMealPayload(m, date)))),
    onSuccess: (created, { message }) => {
      invalidate();
      useToast.getState().showUndo(
        message,
        () => {
          Promise.all(created.map((m) => mealApi.delete(m.id)))
            .catch(() => useToast.getState().show(t("copyDayFailed"), "error"))
            .finally(invalidate);
        },
        () => {},
      );
    },
    onError: () => useToast.getState().show(t("copyDayFailed"), "error"),
  });
}
