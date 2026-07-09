"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { exerciseApi } from "../api";
import { MUSCLE_GROUPS, EQUIPMENT, type MuscleGroup, type Equipment, type ExerciseResponse } from "../types";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";

function muscleGroupColor(category: string | null): string {
  switch (category) {
    case "CHEST":
    case "QUADS":       return "var(--metric-kcal)";
    case "SHOULDERS":
    case "GLUTES":      return "var(--metric-carbs)";
    case "TRICEPS":
    case "FOREARMS":
    case "ABS":         return "var(--metric-fat)";
    case "BACK":        return "var(--metric-water)";
    case "BICEPS":      return "var(--metric-protein)";
    case "HAMSTRINGS":
    case "CALVES":      return "var(--metric-steps)";
    default:            return "var(--metric-weight)";
  }
}

function categoryIcon(e: ExerciseResponse): string {
  if (e.category === "CARDIO") return "directions_run";
  if (e.equipment === "BODYWEIGHT") return "sports_gymnastics";
  return "fitness_center";
}

export function ExercisesView() {
  const t = useTranslations("workouts");
  const tm = useTranslations("workouts.muscleGroups");
  const te = useTranslations("workouts.equipmentTypes");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [categoryFilter, setCategoryFilter] = useState<string>("ALL");
  const [editing, setEditing] = useState<ExerciseResponse | null>(null);
  const [creating, setCreating] = useState(false);

  const equipmentLabel = (e: string | null) => (e ? te(e) : "—");

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.exercises.all(),
    queryFn: exerciseApi.list,
  });

  const filtered = (data ?? []).filter(
    (e) => categoryFilter === "ALL" || e.category === categoryFilter,
  );

  // Build ordered groups: categories in MUSCLE_GROUPS order, then null at end
  const groups: { key: string | null; label: string; items: ExerciseResponse[] }[] = [];
  if (categoryFilter === "ALL") {
    for (const cat of MUSCLE_GROUPS) {
      const items = filtered.filter((e) => e.category === cat);
      if (items.length > 0) groups.push({ key: cat, label: tm(cat), items });
    }
    const uncategorized = filtered.filter((e) => !e.category);
    if (uncategorized.length > 0) groups.push({ key: null, label: t("uncategorized"), items: uncategorized });
  } else {
    groups.push({ key: categoryFilter, label: tm(categoryFilter), items: filtered });
  }

  // Only show category chips that exist in the data (plus ALL)
  const presentCategories = Array.from(
    new Set((data ?? []).map((e) => e.category).filter(Boolean)),
  ) as string[];

  return (
    <div className="flex gap-6">
      <div className="flex-1 min-w-0 flex flex-col gap-4">
        {/* Filter chips + new */}
        <div className="flex flex-wrap items-center gap-2">
          <FilterChip label={t("allFilter")} active={categoryFilter === "ALL"} onClick={() => setCategoryFilter("ALL")} />
          {presentCategories.map((c) => (
            <FilterChip key={c} label={tm(c)} active={categoryFilter === c} onClick={() => setCategoryFilter(c)} />
          ))}
          <button onClick={() => { setCreating(true); setEditing(null); }}
            className="ml-auto flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--primary)", color: "#1E1F18" }}>
            <span className="material-symbols-rounded text-lg">add</span> {t("newExercise")}
          </button>
        </div>

        {isLoading ? (
          <Skeleton variant="table" />
        ) : isError ? (
          <ErrorState onRetry={refetch} />
        ) : filtered.length === 0 ? (
          <EmptyState icon="fitness_center" title={t("noExercisesYet")} body={t("addExercisesBody")} />
        ) : (
          <div className="flex flex-col gap-6">
            {groups.map((group) => (
              <div key={group.key ?? "__none__"} className="flex flex-col gap-2">
                <p className="text-xs font-bold uppercase tracking-widest px-1" style={{ color: "var(--on-surface-variant)" }}>
                  {group.label}
                </p>
                {group.items.map((e) => (
                  <button key={e.id} onClick={() => { setEditing(e); setCreating(false); }}
                    className="flex items-center gap-3 px-4 py-3 rounded-[var(--r-card)] text-left transition-colors"
                    style={{
                      background: "var(--surface)",
                      outline: editing?.id === e.id ? "2px solid var(--primary)" : "none",
                    }}>
                    <div
                      className="shrink-0 w-10 h-10 rounded-xl flex items-center justify-center"
                      style={{
                        background: `color-mix(in srgb, ${muscleGroupColor(e.category)} 15%, transparent)`,
                      }}
                    >
                      <span
                        className="material-symbols-rounded text-xl"
                        style={{ color: muscleGroupColor(e.category) }}
                      >
                        {categoryIcon(e)}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-sm">{e.name}</p>
                      <p className="text-xs" style={{ color: "var(--muted)" }}>
                        {equipmentLabel(e.equipment)}
                      </p>
                    </div>
                    <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>chevron_right</span>
                  </button>
                ))}
              </div>
            ))}
          </div>
        )}
      </div>

      {(editing || creating) && (
        <div className="w-[320px] shrink-0">
          <ExerciseEditor
            key={editing?.id ?? "new"}
            exercise={editing}
            onSaved={() => { setEditing(null); setCreating(false); queryClient.invalidateQueries({ queryKey: queryKeys.exercises.all() }); }}
            onCancel={() => { setEditing(null); setCreating(false); }}
            onDeleted={() => { setEditing(null); setCreating(false); }}
            show={show}
          />
        </div>
      )}
    </div>
  );
}

function FilterChip({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick}
      className="px-3 h-8 rounded-[var(--r-pill)] text-xs font-semibold transition-colors"
      style={{
        background: active ? "var(--primary)" : "var(--surface)",
        color: active ? "#1E1F18" : "var(--on-surface-variant)",
        border: "1px solid var(--outline)",
      }}>
      {label}
    </button>
  );
}

function ExerciseEditor({
  exercise, onSaved, onCancel, onDeleted, show,
}: {
  exercise: ExerciseResponse | null;
  onSaved: () => void;
  onCancel: () => void;
  onDeleted: () => void;
  show: (m: string, v?: "success" | "error" | "warning" | "default") => void;
}) {
  const t = useTranslations("workouts");
  const tm = useTranslations("workouts.muscleGroups");
  const te = useTranslations("workouts.equipmentTypes");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const [name, setName] = useState(exercise?.name ?? "");
  const [category, setCategory] = useState<string>(exercise?.category ?? "");
  const [equipment, setEquipment] = useState<string>(exercise?.equipment ?? "");
  const [description, setDescription] = useState(exercise?.description ?? "");

  const mutation = useMutation({
    mutationFn: () => {
      const body = {
        name,
        category: (category || null) as MuscleGroup | null,
        equipment: (equipment || null) as Equipment | null,
        description: description.trim() || null,
      };
      return exercise ? exerciseApi.update(exercise.id, body) : exerciseApi.create(body);
    },
    onSuccess: () => { show(exercise ? t("exerciseUpdated") : t("exerciseCreated"), "success"); onSaved(); },
    onError: () => show(t("saveExerciseFailed"), "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: () => exerciseApi.delete(exercise!.id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: queryKeys.exercises.all() }); show(t("exerciseDeleted"), "success"); onDeleted(); },
    onError: () => show(t("deleteExerciseFailed"), "error"),
  });

  return (
    <div className="flex flex-col gap-4 p-5 rounded-[var(--r-card)]" style={{ background: "var(--surface)" }}>
      <div className="flex items-center justify-between">
        <h3 className="font-bold text-base">{exercise ? t("editExercise") : t("newExerciseTitle")}</h3>
        <button onClick={onCancel} aria-label={common("close")} className="p-1 rounded-[var(--r-sm)]">
          <span className="material-symbols-rounded">close</span>
        </button>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("exerciseName")}</label>
        <input value={name} onChange={(e) => setName(e.target.value)}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("category")}</label>
        <select value={category} onChange={(e) => setCategory(e.target.value)}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}>
          <option value="">{common("noneOption")}</option>
          {MUSCLE_GROUPS.map((g) => <option key={g} value={g}>{tm(g)}</option>)}
        </select>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("equipment")}</label>
        <select value={equipment} onChange={(e) => setEquipment(e.target.value)}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}>
          <option value="">{common("noneOption")}</option>
          {EQUIPMENT.map((q) => <option key={q} value={q}>{te(q)}</option>)}
        </select>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("exerciseDescription")}</label>
        <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3}
          className="px-3 py-2 rounded-[var(--r-input)] outline-none text-sm resize-none"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="flex gap-2">
        <button onClick={() => mutation.mutate()} disabled={!name.trim() || mutation.isPending}
          className="flex-1 h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-50"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          {mutation.isPending ? common("saving") : common("save")}
        </button>
        {exercise && (
          <button onClick={() => deleteMutation.mutate()} disabled={deleteMutation.isPending}
            className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" }}
            aria-label={t("deleteExerciseAria")}>
            <span className="material-symbols-rounded text-xl">delete</span>
          </button>
        )}
      </div>
    </div>
  );
}
