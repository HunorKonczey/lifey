"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  DndContext, closestCenter, PointerSensor, useSensor, useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext, verticalListSortingStrategy, useSortable, arrayMove,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useTranslations } from "next-intl";
import { templateApi, exerciseApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { MUSCLE_GROUPS } from "../types";
import type {
  WorkoutTemplateResponse, TemplateExerciseEntry, ExerciseResponse,
} from "../types";

function muscleGroupColor(code: string): string {
  switch (code) {
    case "CHEST": case "QUADS":                        return "var(--metric-kcal)";
    case "SHOULDERS": case "GLUTES":                   return "var(--metric-carbs)";
    case "TRICEPS": case "FOREARMS": case "ABS":       return "var(--metric-fat)";
    case "BACK":                                       return "var(--metric-water)";
    case "BICEPS":                                     return "var(--metric-protein)";
    case "HAMSTRINGS": case "CALVES":                  return "var(--metric-steps)";
    default:                                           return "var(--metric-weight)";
  }
}

function templateCategories(t: WorkoutTemplateResponse, exercisesById: Map<number, ExerciseResponse>): string[] {
  const seen = new Set<string>();
  const ordered: string[] = [];
  for (const code of MUSCLE_GROUPS) {
    if (t.exercises.some((e) => exercisesById.get(e.exerciseId)?.category === code)) {
      if (!seen.has(code)) { seen.add(code); ordered.push(code); }
    }
  }
  return ordered;
}

interface TemplatesViewProps {
  /** When provided, admin nav renders a "Kiosztás" button on every row — absent in the own view. */
  onAssign?: (template: WorkoutTemplateResponse) => void;
  /** When provided, admin nav renders a "schedule for a client" button on every row. */
  onSchedule?: (template: WorkoutTemplateResponse) => void;
}

export function TemplatesView({ onAssign, onSchedule }: TemplatesViewProps = {}) {
  const t = useTranslations("workouts");
  const admin = useTranslations("admin.assignDrawer");
  const schedule = useTranslations("admin.schedule");
  const tm = useTranslations("workouts.muscleGroups");
  const [selectedId, setSelectedId] = useState<number | "new" | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.workoutTemplates.all(),
    queryFn: templateApi.list,
  });

  const { data: exercises } = useQuery({
    queryKey: queryKeys.exercises.all(),
    queryFn: exerciseApi.list,
  });

  const selected =
    selectedId === "new" ? null
    : selectedId != null ? (data ?? []).find((t) => t.id === selectedId) ?? null
    : null;

  const exercisesById = new Map((exercises ?? []).map((e) => [e.id, e]));

  return (
    <div className="flex gap-6">
      {/* Master list */}
      <div className="w-[280px] shrink-0 flex flex-col gap-2">
        <button onClick={() => setSelectedId("new")}
          className="flex items-center gap-1 px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm justify-center"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          <span className="material-symbols-rounded text-lg">add</span> {t("newTemplate")}
        </button>

        {isLoading ? (
          <Skeleton variant="table" />
        ) : isError ? (
          <ErrorState onRetry={refetch} />
        ) : (data ?? []).length === 0 ? (
          <EmptyState icon="list_alt" title={t("noTemplates")} body={t("createTemplate")} />
        ) : (
          (data ?? []).map((tpl) => {
            const cats = templateCategories(tpl, exercisesById);
            return (
              <div key={tpl.id}
                data-testid="template-row"
                className="flex items-start gap-3 px-4 py-3 rounded-[var(--r-card)] transition-colors"
                style={{
                  background: "var(--surface)",
                  outline: selectedId === tpl.id ? "2px solid var(--primary)" : "none",
                }}>
                <button onClick={() => setSelectedId(tpl.id)} className="flex items-start gap-3 flex-1 min-w-0 text-left">
                  <span className="material-symbols-rounded text-xl mt-0.5" style={{ color: "var(--tertiary)" }}>list_alt</span>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-sm truncate">{tpl.name}</p>
                    <p className="text-xs mb-1.5" style={{ color: "var(--muted)" }}>{t("exercisesCount", { count: tpl.exercises.length })}</p>
                    {cats.length > 0 && (
                      <div className="flex flex-wrap gap-1">
                        {cats.map((c) => {
                          const color = muscleGroupColor(c);
                          return (
                            <span key={c} className="text-[10px] font-bold leading-none px-2 py-1 rounded-[var(--r-pill)]"
                              style={{ color, background: `color-mix(in srgb, ${color} 15%, transparent)` }}>
                              {tm(c)}
                            </span>
                          );
                        })}
                      </div>
                    )}
                  </div>
                </button>
                {onAssign && (
                  <button onClick={() => onAssign(tpl)}
                    data-testid="assign-template"
                    className="flex items-center gap-1.5 rounded-xl px-3 py-2 text-xs font-extrabold shrink-0 mt-0.5"
                    style={{ background: "rgba(110,154,106,.18)", color: "var(--tertiary)" }}>
                    <span className="material-symbols-rounded text-base">person_add</span> {admin("assignAction")}
                  </button>
                )}
                {onSchedule && (
                  <button onClick={() => onSchedule(tpl)}
                    data-testid="schedule-template"
                    className="flex items-center justify-center rounded-xl w-8 h-8 shrink-0 mt-0.5"
                    style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
                    aria-label={schedule("scheduleForClientAria")}>
                    <span className="material-symbols-rounded text-lg">calendar_month</span>
                  </button>
                )}
              </div>
            );
          })
        )}
      </div>

      {/* Detail editor */}
      <div className="flex-1 min-w-0">
        {selectedId == null ? (
          <div className="flex items-center justify-center h-64 rounded-[var(--r-card)]"
            style={{ background: "var(--surface)", color: "var(--muted)" }}>
            {t("selectOrCreate")}
          </div>
        ) : (
          <TemplateEditor
            key={selectedId}
            template={selected}
            exercises={exercises ?? []}
            onSaved={(id) => setSelectedId(id)}
            onDeleted={() => setSelectedId(null)}
          />
        )}
      </div>
    </div>
  );
}

function TemplateEditor({
  template, exercises, onSaved, onDeleted,
}: {
  template: WorkoutTemplateResponse | null;
  exercises: ExerciseResponse[];
  onSaved: (id: number) => void;
  onDeleted: () => void;
}) {
  const t = useTranslations("workouts");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  // Component is remounted via `key={selectedId}` in the parent, so initializing
  // from props here is safe and avoids syncing state in an effect.
  const [name, setName] = useState(template?.name ?? "");
  const [rows, setRows] = useState<TemplateExerciseEntry[]>(template?.exercises ?? []);
  const [picking, setPicking] = useState(false);
  const [search, setSearch] = useState("");

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 5 } }));
  const exerciseName = (id: number) =>
    exercises.find((e) => e.id === id)?.name ?? `#${id}`;

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      setRows((prev) => {
        const oldIndex = prev.findIndex((r) => r.exerciseId === active.id);
        const newIndex = prev.findIndex((r) => r.exerciseId === over.id);
        return arrayMove(prev, oldIndex, newIndex);
      });
    }
  };

  const available = exercises.filter(
    (e) => !rows.some((r) => r.exerciseId === e.id) &&
      e.name.toLowerCase().includes(search.toLowerCase()),
  );

  const mutation = useMutation({
    mutationFn: () => {
      const body = { name, exercises: rows };
      return template ? templateApi.update(template.id, body) : templateApi.create(body);
    },
    onSuccess: (saved) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutTemplates.all() });
      show(template ? t("templateUpdated") : t("templateCreated"), "success");
      onSaved(saved.id);
    },
    onError: () => show(t("saveTemplateFailed"), "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: () => templateApi.delete(template!.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutTemplates.all() });
      show(t("templateDeleted"), "success");
      onDeleted();
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  return (
    <div className="flex flex-col gap-4 p-5 rounded-[var(--r-card)]" style={{ background: "var(--surface)" }}>
      <input value={name} onChange={(e) => setName(e.target.value)} placeholder={t("templateNamePlaceholder")}
        className="px-3 h-11 rounded-[var(--r-input)] outline-none text-base font-bold"
        style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />

      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
        <SortableContext items={rows.map((r) => r.exerciseId)} strategy={verticalListSortingStrategy}>
          <div className="flex flex-col gap-2">
            {rows.map((row) => (
              <SortableRow key={row.exerciseId} row={row} name={exerciseName(row.exerciseId)}
                onSetsChange={(n) => setRows((prev) => prev.map((r) =>
                  r.exerciseId === row.exerciseId ? { ...r, targetSets: n } : r))}
                onRemove={() => setRows((prev) => prev.filter((r) => r.exerciseId !== row.exerciseId))} />
            ))}
          </div>
        </SortableContext>
      </DndContext>

      {/* Add exercise */}
      {picking ? (
        <div className="flex flex-col gap-2 p-3 rounded-[var(--r-md)]" style={{ background: "var(--surface-container)" }}>
          <input autoFocus value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t("searchExercisesPlaceholder")}
            className="px-3 h-9 rounded-[var(--r-sm)] outline-none text-sm"
            style={{ background: "var(--surface)", border: "1px solid var(--outline)" }} />
          <div className="flex flex-col gap-1 max-h-48 overflow-y-auto">
            {available.map((e) => (
              <button key={e.id} onClick={() => {
                setRows((prev) => [...prev, { exerciseId: e.id, targetSets: 3 }]);
                setSearch(""); setPicking(false);
              }} className="text-left px-3 py-1.5 rounded-[var(--r-sm)] text-sm transition-colors hover:bg-surface">
                {e.name}
              </button>
            ))}
            {available.length === 0 && <p className="text-xs text-center py-2" style={{ color: "var(--muted)" }}>{t("noExercisesFound")}</p>}
          </div>
        </div>
      ) : (
        <button onClick={() => setPicking(true)}
          className="py-2.5 rounded-[var(--r-md)] text-sm font-semibold flex items-center justify-center gap-1"
          style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}>
          <span className="material-symbols-rounded text-lg">add</span> {t("addExercise")}
        </button>
      )}

      <div className="flex gap-2 mt-1">
        <button onClick={() => mutation.mutate()} disabled={!name.trim() || rows.length === 0 || mutation.isPending}
          className="flex-1 h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-50"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          {mutation.isPending ? common("saving") : t("saveTemplate")}
        </button>
        {template && (
          <button onClick={() => deleteMutation.mutate()} disabled={deleteMutation.isPending}
            className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" }}
            aria-label={t("deleteTemplateAria")}>
            <span className="material-symbols-rounded text-xl">delete</span>
          </button>
        )}
      </div>
    </div>
  );
}

function SortableRow({
  row, name, onSetsChange, onRemove,
}: {
  row: TemplateExerciseEntry;
  name: string;
  onSetsChange: (n: number) => void;
  onRemove: () => void;
}) {
  const t = useTranslations("workouts");
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } =
    useSortable({ id: row.exerciseId });

  return (
    <div ref={setNodeRef}
      style={{
        transform: CSS.Transform.toString(transform),
        transition,
        opacity: isDragging ? 0.6 : 1,
        background: "var(--surface-container)",
      }}
      className="flex items-center gap-2 px-3 py-2.5 rounded-[var(--r-md)]">
      <button {...attributes} {...listeners} className="cursor-grab touch-none" style={{ color: "var(--muted)" }} aria-label={t("dragToReorderAria")}>
        <span className="material-symbols-rounded">drag_indicator</span>
      </button>
      <span className="flex-1 text-sm font-semibold truncate">{name}</span>

      {/* Sets stepper */}
      <div className="flex items-center gap-1">
        <button onClick={() => onSetsChange(Math.max(1, row.targetSets - 1))}
          className="w-6 h-6 rounded-[var(--r-sm)] flex items-center justify-center" style={{ background: "var(--surface-highest)" }}>
          <span className="material-symbols-rounded text-base">remove</span>
        </button>
        <span className="w-12 text-center text-sm tabular font-semibold">{t("setsSuffix", { count: row.targetSets })}</span>
        <button onClick={() => onSetsChange(row.targetSets + 1)}
          className="w-6 h-6 rounded-[var(--r-sm)] flex items-center justify-center" style={{ background: "var(--surface-highest)" }}>
          <span className="material-symbols-rounded text-base">add</span>
        </button>
      </div>

      <button onClick={onRemove} style={{ color: "var(--muted)" }} aria-label={t("removeExerciseAria")}>
        <span className="material-symbols-rounded text-lg">close</span>
      </button>
    </div>
  );
}
