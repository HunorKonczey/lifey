"use client";

import { useRef, useState } from "react";
import { Button, Icon } from "@/components/ds";
import { CopyFromDayView } from "@/features/nutrition/components/CopyFromDayPopover";
import type { MealResponse, MealType } from "@/features/nutrition/types";

const meal = (id: number, day: number, h: number, m: number, mealType: MealType, name: string | null, foods: number, kcal: number): MealResponse => ({
  id,
  dateTime: new Date(2026, 8, day, h, m).toISOString(),
  mealType,
  name,
  entries: Array.from({ length: foods }, (_, i) => ({
    foodId: id * 10 + i,
    foodName: `Étel ${i + 1}`,
    quantityInGrams: 100,
    calories: kcal / foods,
    protein: 10,
    carbs: 10,
    fat: 5,
  })),
});

// Viewing 2026-09-27; 26th has three meals, the 25th one, the 20th two, the 27th (the viewed day) one.
const MEALS: MealResponse[] = [
  meal(1, 26, 7, 15, "BREAKFAST", null, 3, 379),
  meal(2, 26, 12, 30, "LUNCH", "Csirkés rizstál brokkolival", 3, 528),
  meal(3, 26, 19, 40, "DINNER", null, 2, 612),
  meal(4, 25, 15, 40, "SNACK", null, 1, 134),
  meal(5, 20, 8, 0, "BREAKFAST", null, 2, 310),
  meal(6, 20, 13, 0, "LUNCH", null, 2, 640),
  meal(7, 27, 7, 30, "BREAKFAST", null, 1, 250),
];
const TODAY = new Date(2026, 8, 27, 10, 0);

/** The copy-from-day popover (W2.9) on a fixed set of meals; "Copy" only logs the ids it would copy. */
export function CopyFromDaySection() {
  const [open, setOpen] = useState(false);
  const [log, setLog] = useState("—");
  const anchor = useRef<HTMLSpanElement>(null);

  return (
    <div className="flex flex-col gap-3">
      <span ref={anchor} className="inline-flex self-start">
        <Button variant="secondary" onClick={() => setOpen((o) => !o)} data-testid="open-copy-from-day">
          <Icon name="event_repeat" size={20} />
          Copy from an earlier day
        </Button>
      </span>
      <p data-testid="copy-log" className="type-body-s">
        Copied: {log}
      </p>
      <CopyFromDayView
        open={open}
        onClose={() => setOpen(false)}
        anchorRef={anchor}
        meals={MEALS}
        target={TODAY}
        today={TODAY}
        onCopy={(meals) => {
          setLog(meals.map((m) => m.id).join(", "));
          setOpen(false);
        }}
      />
    </div>
  );
}
