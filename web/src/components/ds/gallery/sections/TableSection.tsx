"use client";

import { useState } from "react";
import { Button } from "../../Button";
import { DataTable, type DataTableColumn } from "../../table/DataTable";

interface Food {
  id: number;
  name: string;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
}

const FOODS: Food[] = [
  { id: 1, name: "Chicken breast", kcal: 165, protein: 31, carbs: 0, fat: 3.6 },
  { id: 2, name: "Brown rice", kcal: 123, protein: 2.7, carbs: 26, fat: 1 },
  { id: 3, name: "Broccoli", kcal: 34, protein: 2.8, carbs: 7, fat: 0.4 },
  { id: 4, name: "Salmon", kcal: 208, protein: 20, carbs: 0, fat: 13 },
  { id: 5, name: "Greek yogurt", kcal: 59, protein: 10, carbs: 3.6, fat: 0.4 },
  { id: 6, name: "Oats", kcal: 389, protein: 17, carbs: 66, fat: 7 },
  { id: 7, name: "Almonds", kcal: 579, protein: 21, carbs: 22, fat: 50 },
  { id: 8, name: "Banana", kcal: 89, protein: 1.1, carbs: 23, fat: 0.3 },
  { id: 9, name: "Sweet potato", kcal: 86, protein: 1.6, carbs: 20, fat: 0.1 },
  { id: 10, name: "Egg", kcal: 155, protein: 13, carbs: 1.1, fat: 11 },
  { id: 11, name: "Tuna", kcal: 132, protein: 28, carbs: 0, fat: 1.3 },
  { id: 12, name: "Cottage cheese", kcal: 98, protein: 11, carbs: 3.4, fat: 4.3 },
  { id: 13, name: "Lentils", kcal: 116, protein: 9, carbs: 20, fat: 0.4 },
  { id: 14, name: "Olive oil", kcal: 884, protein: 0, carbs: 0, fat: 100 },
  { id: 15, name: "Spinach", kcal: 23, protein: 2.9, carbs: 3.6, fat: 0.4 },
  { id: 16, name: "Quinoa", kcal: 120, protein: 4.4, carbs: 21, fat: 1.9 },
  { id: 17, name: "Peanut butter", kcal: 588, protein: 25, carbs: 20, fat: 50 },
  { id: 18, name: "Avocado", kcal: 160, protein: 2, carbs: 9, fat: 15 },
];

const COLUMNS: DataTableColumn<Food>[] = [
  { key: "name", header: "Name", render: (f) => f.name, sort: (f) => f.name },
  {
    key: "kcal",
    header: "Kcal / 100g",
    align: "right",
    metricDot: "var(--m-kcal)",
    render: (f) => f.kcal,
    sort: (f) => f.kcal,
  },
  {
    key: "protein",
    header: "Protein",
    align: "right",
    metricDot: "var(--m-protein)",
    render: (f) => `${f.protein} g`,
    sort: (f) => f.protein,
  },
  {
    key: "carbs",
    header: "Carbs",
    align: "right",
    metricDot: "var(--m-carbs)",
    render: (f) => `${f.carbs} g`,
    sort: (f) => f.carbs,
  },
  {
    key: "fat",
    header: "Fat",
    align: "right",
    metricDot: "var(--m-fat)",
    render: (f) => `${f.fat} g`,
    sort: (f) => f.fat,
  },
];

/** D-W0.15 — DataTable v2 against the DS-03 foods sample: search, sortable
 *  macro columns with a metric dot, comfortable/compact density, a row "…"
 *  menu, and a card-row layout under 768px. */
export function TableSection() {
  const [search, setSearch] = useState("");
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [lastAction, setLastAction] = useState("—");

  const filtered = FOODS.filter((f) => f.name.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="flex flex-col gap-2">
      <DataTable
        aria-label="Foods"
        columns={COLUMNS}
        rows={filtered}
        rowKey={(f) => f.id}
        selectedKey={selectedId}
        onRowOpen={(f) => setSelectedId(f.id)}
        pageSize={10}
        search={{ value: search, onChange: setSearch, placeholder: "Search foods… (press /)" }}
        action={
          <Button size="default" onClick={() => setLastAction("Add food clicked")}>
            Add food
          </Button>
        }
        totalLabel={(n) => `${n} foods`}
        rowMenuLabel={(f) => `More actions for ${f.name}`}
        renderCardRow={(f) => ({
          title: f.name,
          meta: `${f.kcal} kcal/100g`,
          value: `${f.protein} g protein`,
        })}
        rowMenu={(f) => [
          { label: "Edit", icon: "edit", onSelect: () => setLastAction(`Edit ${f.name}`) },
          { label: "Delete", icon: "delete", destructive: true, onSelect: () => setLastAction(`Delete ${f.name}`) },
        ]}
      />
      <p className="type-body-s" style={{ color: "var(--text-3)" }}>
        Last action: {lastAction}
      </p>
    </div>
  );
}
