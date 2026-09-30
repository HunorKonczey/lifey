"use client";

import { useEffect, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  DndContext, KeyboardSensor, PointerSensor, closestCenter, useSensor, useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import { SortableContext, arrayMove, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useTranslations } from "next-intl";
import { Button, Icon, IconButton, TextField } from "@/components/ds";
import { ConfirmModal } from "@/components/ds/overlay/ConfirmModal";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { templateApi } from "../api";
import type { ExerciseResponse, TemplateExerciseEntry, WorkoutTemplateResponse } from "../types";

/** True when the edited name / exercise list differ from the saved template (or a new one has anything in it). */
export function isTemplateDirty(template: WorkoutTemplateResponse | null, name: string, rows: readonly TemplateExerciseEntry[]): boolean {
  if (!template) return name.trim() !== "" || rows.length > 0;
  return (
    template.name !== name ||
    template.exercises.length !== rows.length ||
    template.exercises.some((e, i) => e.exerciseId !== rows[i].exerciseId || e.targetSets !== rows[i].targetSets)
  );
}

/**
 * The template editor of the Templates tab (W3.11, W3-F, client-015): the name, the exercise rows with their set
 * stepper — reordered by dragging the handle with the mouse or, from the keyboard, Space on the handle, ↑/↓, Space —
 * "Gyakorlat hozzáadása" with its search, Save and Delete (asks first). Lives in the right panel from 1280 px and
 * in a drawer below it (`bare` drops the heading the drawer already has). Remounted per template via `key`.
 */
export function TemplateEditorPanel({
  template,
  exercises,
  bare = false,
  onDirtyChange,
  onSaved,
  onDeleted,
}: {
  template: WorkoutTemplateResponse | null;
  exercises: ExerciseResponse[];
  bare?: boolean;
  onDirtyChange?: (dirty: boolean) => void;
  onSaved: (id: number) => void;
  onDeleted: () => void;
}) {
  const t = useTranslations("workouts");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [name, setName] = useState(template?.name ?? "");
  const [rows, setRows] = useState<TemplateExerciseEntry[]>(template?.exercises ?? []);
  const [picking, setPicking] = useState(false);
  const [search, setSearch] = useState("");
  const [confirmingDelete, setConfirmingDelete] = useState(false);

  const dirty = isTemplateDirty(template, name, rows);
  useEffect(() => {
    onDirtyChange?.(dirty);
  }, [dirty, onDirtyChange]);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );
  const exerciseName = (id: number) => exercises.find((e) => e.id === id)?.name ?? `#${id}`;

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      setRows((prev) => arrayMove(prev, prev.findIndex((r) => r.exerciseId === active.id), prev.findIndex((r) => r.exerciseId === over.id)));
    }
  };

  const available = exercises.filter((e) => !rows.some((r) => r.exerciseId === e.id) && e.name.toLowerCase().includes(search.toLowerCase()));

  const saveMutation = useMutation({
    mutationFn: () => {
      const body = { name: name.trim(), exercises: rows };
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
    <div className="flex flex-col gap-4" data-testid="template-editor">
      {!bare && <h2 className="type-title">{template ? t("editTemplate") : t("newTemplate")}</h2>}

      <TextField label={t("templateNameLabel")} value={name} onChange={(e) => setName(e.target.value)} placeholder={t("templateNamePlaceholder")} autoFocus={!template} />

      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
        <SortableContext items={rows.map((r) => r.exerciseId)} strategy={verticalListSortingStrategy}>
          <div className="flex flex-col gap-2">
            {rows.map((row) => (
              <SortableRow
                key={row.exerciseId}
                row={row}
                name={exerciseName(row.exerciseId)}
                onSetsChange={(n) => setRows((prev) => prev.map((r) => (r.exerciseId === row.exerciseId ? { ...r, targetSets: n } : r)))}
                onRemove={() => setRows((prev) => prev.filter((r) => r.exerciseId !== row.exerciseId))}
              />
            ))}
          </div>
        </SortableContext>
      </DndContext>

      {picking ? (
        <div className="flex flex-col gap-2 p-3" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
          <TextField autoFocus leadingIcon="search" size="dense" value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t("searchExercisesPlaceholder")} aria-label={t("searchExercisesPlaceholder")} />
          <div className="flex max-h-48 flex-col gap-1 overflow-y-auto">
            {available.map((e) => (
              <button
                key={e.id}
                type="button"
                onClick={() => {
                  setRows((prev) => [...prev, { exerciseId: e.id, targetSets: 3 }]);
                  setSearch("");
                  setPicking(false);
                }}
                className="lifey-button type-body-s px-3 py-2 text-left"
                style={{ borderRadius: "var(--r-tag)" }}
              >
                {e.name}
              </button>
            ))}
            {available.length === 0 && (
              <p className="type-body-s py-2 text-center" style={{ color: "var(--text-3)" }}>
                {t("noExercisesFound")}
              </p>
            )}
          </div>
        </div>
      ) : (
        <Button variant="secondary" onClick={() => setPicking(true)}>
          <Icon name="add" size={20} />
          {t("addExercise")}
        </Button>
      )}

      <div className="flex gap-2">
        <Button className="flex-1" onClick={() => saveMutation.mutate()} disabled={!name.trim() || rows.length === 0 || saveMutation.isPending}>
          {saveMutation.isPending ? common("saving") : t("saveTemplate")}
        </Button>
        {template && (
          <Button variant="danger" onClick={() => setConfirmingDelete(true)} disabled={deleteMutation.isPending} aria-label={t("deleteTemplateAria")}>
            <Icon name="delete" size={20} />
          </Button>
        )}
      </div>

      <ConfirmModal
        open={confirmingDelete}
        onClose={() => setConfirmingDelete(false)}
        onConfirm={() => {
          setConfirmingDelete(false);
          deleteMutation.mutate();
        }}
        icon="delete"
        title={t("deleteTemplateTitle", { name: template?.name ?? "" })}
        body={t("deleteTemplateBody")}
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />
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
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: row.exerciseId });

  return (
    <div
      ref={setNodeRef}
      data-testid="template-exercise-row"
      style={{
        transform: CSS.Transform.toString(transform),
        transition,
        opacity: isDragging ? 0.6 : 1,
        background: "var(--nested)",
        borderRadius: "var(--r-control)",
      }}
      className="flex items-center gap-2 px-3 py-2.5"
    >
      <button {...attributes} {...listeners} type="button" className="cursor-grab touch-none" style={{ color: "var(--text-3)" }} aria-label={t("dragToReorderAria")}>
        <Icon name="drag_indicator" size={22} />
      </button>
      <span className="type-body-s min-w-0 flex-1 truncate" style={{ fontWeight: 700 }}>
        {name}
      </span>

      <div className="flex items-center gap-1" role="group" aria-label={t("targetSetsAria", { name })}>
        <IconButton icon="remove" label={t("fewerSetsAria")} size={32} onClick={() => onSetsChange(Math.max(1, row.targetSets - 1))} />
        <span className="type-body-s tabular w-14 text-center" style={{ fontWeight: 700 }} data-testid="template-sets">
          {t("setsSuffix", { count: row.targetSets })}
        </span>
        <IconButton icon="add" label={t("moreSetsAria")} size={32} onClick={() => onSetsChange(row.targetSets + 1)} />
      </div>

      <IconButton icon="close" label={t("removeExerciseAria")} size={32} onClick={onRemove} />
    </div>
  );
}
