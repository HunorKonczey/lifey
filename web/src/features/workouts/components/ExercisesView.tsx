"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { exerciseApi } from "../api";
import { MUSCLE_GROUPS, EQUIPMENT, type MuscleGroup, type Equipment, type ExerciseResponse } from "../types";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { humanizeEnum } from "@/lib/utils/format";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";

export function ExercisesView() {
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [categoryFilter, setCategoryFilter] = useState<string>("ALL");
  const [editing, setEditing] = useState<ExerciseResponse | null>(null);
  const [creating, setCreating] = useState(false);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.exercises.all(),
    queryFn: exerciseApi.list,
  });

  const exercises = (data ?? []).filter(
    (e) => categoryFilter === "ALL" || e.category === categoryFilter,
  );

  // Only show category chips that exist in the data (plus ALL)
  const presentCategories = Array.from(
    new Set((data ?? []).map((e) => e.category).filter(Boolean)),
  ) as string[];

  return (
    <div className="flex gap-6">
      <div className="flex-1 min-w-0 flex flex-col gap-4">
        {/* Filter chips + new */}
        <div className="flex flex-wrap items-center gap-2">
          <FilterChip label="All" active={categoryFilter === "ALL"} onClick={() => setCategoryFilter("ALL")} />
          {presentCategories.map((c) => (
            <FilterChip key={c} label={humanizeEnum(c)} active={categoryFilter === c} onClick={() => setCategoryFilter(c)} />
          ))}
          <button onClick={() => { setCreating(true); setEditing(null); }}
            className="ml-auto flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--primary)", color: "#1E1F18" }}>
            <span className="material-symbols-rounded text-lg">add</span> New
          </button>
        </div>

        {isLoading ? (
          <Skeleton variant="table" />
        ) : isError ? (
          <ErrorState onRetry={refetch} />
        ) : exercises.length === 0 ? (
          <EmptyState icon="fitness_center" title="No exercises yet" body="Add exercises to build workout templates." />
        ) : (
          <div className="flex flex-col gap-2">
            {exercises.map((e) => (
              <button key={e.id} onClick={() => { setEditing(e); setCreating(false); }}
                className="flex items-center gap-3 px-4 py-3 rounded-[var(--r-card)] text-left transition-colors"
                style={{
                  background: "var(--surface)",
                  outline: editing?.id === e.id ? "2px solid var(--primary)" : "none",
                }}>
                <span className="material-symbols-rounded text-xl" style={{ color: "var(--tertiary)" }}>exercise</span>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-sm">{e.name}</p>
                  <p className="text-xs" style={{ color: "var(--muted)" }}>
                    {humanizeEnum(e.equipment)} · {humanizeEnum(e.category)}
                  </p>
                </div>
                <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>chevron_right</span>
              </button>
            ))}
          </div>
        )}
      </div>

      {(editing || creating) && (
        <div className="w-[320px] shrink-0">
          <ExerciseEditor
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
  const queryClient = useQueryClient();
  const [name, setName] = useState(exercise?.name ?? "");
  const [category, setCategory] = useState<string>(exercise?.category ?? "");
  const [equipment, setEquipment] = useState<string>(exercise?.equipment ?? "");

  const mutation = useMutation({
    mutationFn: () => {
      const body = {
        name,
        category: (category || null) as MuscleGroup | null,
        equipment: (equipment || null) as Equipment | null,
      };
      return exercise ? exerciseApi.update(exercise.id, body) : exerciseApi.create(body);
    },
    onSuccess: () => { show(exercise ? "Exercise updated" : "Exercise created", "success"); onSaved(); },
    onError: () => show("Failed to save", "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: () => exerciseApi.delete(exercise!.id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: queryKeys.exercises.all() }); show("Exercise deleted", "success"); onDeleted(); },
    onError: () => show("Failed to delete", "error"),
  });

  return (
    <div className="flex flex-col gap-4 p-5 rounded-[var(--r-card)]" style={{ background: "var(--surface)" }}>
      <div className="flex items-center justify-between">
        <h3 className="font-bold text-base">{exercise ? "Edit exercise" : "New exercise"}</h3>
        <button onClick={onCancel} aria-label="Close" className="p-1 rounded-[var(--r-sm)]">
          <span className="material-symbols-rounded">close</span>
        </button>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Name</label>
        <input value={name} onChange={(e) => setName(e.target.value)}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Category</label>
        <select value={category} onChange={(e) => setCategory(e.target.value)}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}>
          <option value="">— None —</option>
          {MUSCLE_GROUPS.map((g) => <option key={g} value={g}>{humanizeEnum(g)}</option>)}
        </select>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Equipment</label>
        <select value={equipment} onChange={(e) => setEquipment(e.target.value)}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}>
          <option value="">— None —</option>
          {EQUIPMENT.map((q) => <option key={q} value={q}>{humanizeEnum(q)}</option>)}
        </select>
      </div>

      <div className="flex gap-2">
        <button onClick={() => mutation.mutate()} disabled={!name.trim() || mutation.isPending}
          className="flex-1 h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-50"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          {mutation.isPending ? "Saving…" : "Save"}
        </button>
        {exercise && (
          <button onClick={() => deleteMutation.mutate()} disabled={deleteMutation.isPending}
            className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" }}
            aria-label="Delete exercise">
            <span className="material-symbols-rounded text-xl">delete</span>
          </button>
        )}
      </div>
    </div>
  );
}
