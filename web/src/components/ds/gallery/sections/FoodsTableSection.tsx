"use client";

import { useState } from "react";
import { FoodEditor } from "@/features/nutrition/components/FoodEditor";
import { readGalleryOffPreference, useFixtureOff, useFixtureOffRequestCount, writeGalleryOffPreference } from "../offFixture";
import { FoodsTable } from "@/features/nutrition/components/FoodsTable";
import type { FoodUsage } from "@/features/nutrition/usage";
import type { FoodResponse } from "@/features/nutrition/types";

const food = (id: number, name: string, kcal: number, p: number, c: number, f: number): FoodResponse => ({
  id,
  name,
  caloriesPer100g: kcal,
  proteinPer100g: p,
  carbsPer100g: c,
  fatPer100g: f,
  barcode: null,
  hidden: false,
});

const FOODS: FoodResponse[] = [
  food(1, "Zabpehely", 372, 13.5, 58.7, 7),
  food(2, "Görög joghurt 2%", 73, 9.9, 3.9, 2),
  food(3, "Csirkemell", 165, 31, 0, 3.6),
  food(4, "Barna rizs", 123, 2.7, 25.6, 1),
  food(5, "Brokkoli", 34, 2.8, 6.6, 0.4),
  food(6, "Édesburgonya", 86, 1.6, 20.1, 0.1),
  food(7, "Alma", 52, 0.3, 13.8, 0.2),
  food(8, "Banán", 89, 1.1, 22.8, 0.3),
  food(9, "Tojás", 143, 12.6, 0.7, 9.5),
  food(10, "Lazac", 208, 20, 0, 13),
  food(11, "Olívaolaj", 884, 0, 0, 100),
  food(12, "Mandula", 579, 21.2, 21.6, 49.9),
  food(13, "Túró rudi", 367, 13, 41, 17),
  // the macros give 72 kcal against the stated 73: the canvas' info line
  food(14, "Kefir", 73, 5, 8, 2.2),
  // way off: 100 kcal stated, the macros give 180
  food(15, "Házi granola", 100, 5, 20, 8.9),
  food(16, "Fehér kenyér", 266, 8.9, 49, 3.2),
  food(17, "Tej 2,8%", 58, 3.3, 4.7, 2.8),
  food(18, "Avokádó", 160, 2, 8.5, 14.7),
];

// Viewing Sep 27, 2026.
const NOW = new Date(2026, 8, 27, 10, 0);
const at = (day: number) => new Date(2026, 8, day, 12).getTime();
const USAGE = new Map<number, FoodUsage>([
  [1, { lastUsedAt: at(27), useCount: 12, lastGrams: 60 }],
  [2, { lastUsedAt: at(26), useCount: 9, lastGrams: 150 }],
  [3, { lastUsedAt: at(25), useCount: 7, lastGrams: 150 }],
  [4, { lastUsedAt: at(20), useCount: 4, lastGrams: 180 }],
  [5, { lastUsedAt: at(2), useCount: 1, lastGrams: 90 }],
]);

/** The foods table with its editor panel (W2.10): 18 foods, "Utoljára" from a few logged ones; actions only log what they would do. */
export function FoodsTableSection() {
  const [editing, setEditing] = useState<{ food: FoodResponse | null; key: string } | null>(null);
  const [log, setLog] = useState("—");
  const offRequests = useFixtureOffRequestCount();

  return (
    <div className="flex flex-col gap-3">
      <p data-testid="foods-log" className="type-body-s">
        Last action: {log}
      </p>
      <p data-testid="foods-off-requests" className="type-body-s">
        OpenFoodFacts requests: {offRequests}
      </p>
      <div className="flex flex-col gap-6 xl:flex-row xl:items-start">
        <div className="min-w-0 flex-1">
          <FoodsTable
            foods={FOODS}
            usage={USAGE}
            now={NOW}
            selectedId={editing?.food?.id ?? null}
            onOpen={(f) => setEditing({ food: f, key: `food:${f.id}` })}
            onNew={() => setEditing({ food: null, key: `new:${Date.now()}` })}
            onDuplicate={(f) => setLog(`duplicate ${f.name}`)}
            onLogToday={(f) => setLog(`log ${f.name}`)}
            onDelete={(f) => setLog(`delete ${f.name}`)}
          />
        </div>
        {editing && (
          <div className="w-full xl:w-[380px] xl:shrink-0">
            <FoodEditor
              key={editing.key}
              food={editing.food}
              onSave={(r) => {
                setLog(`save ${r.name}|${r.caloriesPer100g}|${r.proteinPer100g}|${r.carbsPer100g}|${r.fatPer100g}`);
                setEditing(null);
              }}
              onCancel={() => setEditing(null)}
              onLookupBarcode={(b) => setLog(`lookup ${b}`)}
              useOff={useFixtureOff}
              initialOffChecked={readGalleryOffPreference()}
              onOffCheckedChange={writeGalleryOffPreference}
            />
          </div>
        )}
      </div>
    </div>
  );
}
