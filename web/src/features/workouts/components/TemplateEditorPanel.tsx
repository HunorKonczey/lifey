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
import { Button, Icon, IconButton, TextField, TintedChip } from "@/components/ds";
import { ConfirmModal } from "@/components/ds/overlay/ConfirmModal";
import { queryKeys } from "@/lib/api/queryKeys";
import { templateTotals } from "@/features/trainer/templateUsage";
import { formatRest } from "../exerciseUi";
import { useToast } from "@/lib/hooks/useToast";
import { templateApi } from "../api";
import { MAX_TEMPLATE_MINUTES, MAX_TEMPLATE_REPS, buildTemplateRequest, sanitizeCount } from "../templateRequest";
import type { ExerciseResponse, TemplateExerciseEntry, WorkoutTemplateResponse } from "../types";

/** True when the edited name / exercise list differ from the saved template (or a new one has anything in it). */
export function isTemplateDirty(
  template: WorkoutTemplateResponse | null,
  name: string,
  rows: readonly TemplateExerciseEntry[],
  /** The edited duration; left out where the duration is not edited. */
  durationMinutes?: number | null,
): boolean {
  if (!template) return name.trim() !== "" || rows.length > 0 || (durationMinutes ?? null) !== null;
  return (
    template.name !== name ||
    template.exercises.length !== rows.length ||
    template.exercises.some(
      (e, i) =>
        e.exerciseId !== rows[i].exerciseId ||
        e.targetSets !== rows[i].targetSets ||
        (e.targetReps ?? null) !== (rows[i].targetReps ?? null),
    ) ||
    (durationMinutes !== undefined && (template.durationMinutes ?? null) !== durationMinutes)
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
  trainer,
}: {
  template: WorkoutTemplateResponse | null;
  exercises: ExerciseResponse[];
  bare?: boolean;
  onDirtyChange?: (dirty: boolean) => void;
  onSaved: (id: number) => void;
  onDeleted: () => void;
  /**
   * The trainer's variant (W9-A): a header with the name, the "Nem mentett" chip and a close button, the totals
   * line, a detail line per exercise, and a footer that says how many clients' future workouts a save reaches.
   */
  trainer?: { clientCount: number; /** Of them, who have it in a schedule or program still running (LIF-106). */ scheduledCount?: number; onClose: () => void };
}) {
  const t = useTranslations("workouts");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [name, setName] = useState(template?.name ?? "");
  const [rows, setRows] = useState<TemplateExerciseEntry[]>(template?.exercises ?? []);
  // The author's own duration in minutes (LIF-106); null = not said, the estimate shows instead.
  const [duration, setDuration] = useState<number | null>(template?.durationMinutes ?? null);
  const [picking, setPicking] = useState(false);
  const [search, setSearch] = useState("");
  const [confirmingDelete, setConfirmingDelete] = useState(false);

  const dirty = isTemplateDirty(template, name, rows, duration);
  const totals = templateTotals(rows, duration);
  const estimate = templateTotals(rows).minutes;
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

  const discard = () => {
    setName(template?.name ?? "");
    setRows(template?.exercises ?? []);
    setDuration(template?.durationMinutes ?? null);
  };
  const exerciseDetail = (e: ExerciseResponse | undefined) => {
    if (!e) return undefined;
    const group = e.category ? t(`muscleGroups.${e.category}`) : null;
    const rest = formatRest(e.defaultRestSeconds);
    return [group, rest ? t("restShort", { time: rest }) : null].filter(Boolean).join(" · ") || undefined;
  };

  const available = exercises.filter((e) => !rows.some((r) => r.exerciseId === e.id) && e.name.toLowerCase().includes(search.toLowerCase()));

  const saveMutation = useMutation({
    mutationFn: () => {
      const body = buildTemplateRequest(template, name, rows, duration);
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
      {trainer ? (
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <h2 className="type-title min-w-0 flex-1 truncate">{name.trim() || template?.name || t("newTemplate")}</h2>
            {dirty && <TintedChip label={t("unsavedChip")} color="var(--primary)" />}
            {!bare && <IconButton icon="close" label={common("close")} size={32} onClick={trainer.onClose} />}
          </div>
          <p className="type-body-s tabular" style={{ color: "var(--text-2)" }} data-testid="template-totals">
            {totals.stated
              ? t("templateTotalsStated", { exercises: totals.exercises, sets: totals.sets, minutes: totals.minutes })
              : t("templateTotals", { exercises: totals.exercises, sets: totals.sets, minutes: totals.minutes })}
          </p>
        </div>
      ) : (
        !bare && <h2 className="type-title">{template ? t("editTemplate") : t("newTemplate")}</h2>
      )}

      <TextField label={t("templateNameLabel")} value={name} onChange={(e) => setName(e.target.value)} placeholder={t("templateNamePlaceholder")} autoFocus={!template} />

      {trainer && (
        <TextField
          label={t("templateDurationLabel")}
          inputMode="numeric"
          value={duration ?? ""}
          onChange={(e) => setDuration(sanitizeCount(e.target.value, MAX_TEMPLATE_MINUTES))}
          placeholder={String(estimate)}
          hint={t("templateDurationHint", { minutes: estimate })}
          data-testid="template-duration"
        />
      )}

      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
        <SortableContext items={rows.map((r) => r.exerciseId)} strategy={verticalListSortingStrategy}>
          <div className="flex flex-col gap-2">
            {rows.map((row) => (
              <SortableRow
                key={row.exerciseId}
                row={row}
                name={exerciseName(row.exerciseId)}
                detail={trainer ? exerciseDetail(exercises.find((e) => e.id === row.exerciseId)) : undefined}
                showReps={!!trainer}
                onRepsChange={(n) => setRows((prev) => prev.map((r) => (r.exerciseId === row.exerciseId ? { ...r, targetReps: n } : r)))}
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

      {trainer && (
        <p className="type-body-s" style={{ color: "var(--text-2)" }} data-testid="template-impact">
          {template ? t("templateImpact", { count: trainer.clientCount }) : t("templateImpactNew")}
          {template && (trainer.scheduledCount ?? 0) > 0 && ` ${t("templateImpactScheduled", { count: trainer.scheduledCount ?? 0 })}`}
        </p>
      )}
      <div className="flex gap-2">
        {trainer && (
          <Button variant="secondary" onClick={template ? discard : trainer.onClose} disabled={template != null && !dirty}>
            {t("discardChanges")}
          </Button>
        )}
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
  row, name, detail, showReps, onRepsChange, onSetsChange, onRemove,
}: {
  row: TemplateExerciseEntry;
  name: string;
  detail?: string;
  /** The trainer's editor asks for repetitions per set too (LIF-106). */
  showReps?: boolean;
  onRepsChange: (n: number | null) => void;
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
      <span className="min-w-0 flex-1">
        <span className="type-body-s block truncate" style={{ fontWeight: 700 }}>
          {name}
        </span>
        {detail && (
          <span className="type-body-s block truncate" style={{ color: "var(--text-3)" }}>
            {detail}
          </span>
        )}
      </span>

      <div className="flex items-center gap-1" role="group" aria-label={t("targetSetsAria", { name })}>
        <IconButton icon="remove" label={t("fewerSetsAria")} size={32} onClick={() => onSetsChange(Math.max(1, row.targetSets - 1))} />
        <span className="type-body-s tabular w-14 text-center" style={{ fontWeight: 700 }} data-testid="template-sets">
          {t("setsSuffix", { count: row.targetSets })}
        </span>
        <IconButton icon="add" label={t("moreSetsAria")} size={32} onClick={() => onSetsChange(row.targetSets + 1)} />
      </div>

      {showReps && (
        <span aria-hidden className="type-body-s" style={{ color: "var(--text-3)" }}>×</span>
      )}
      {showReps && (
        <TextField
          size="dense"
          className="w-16 shrink-0"
          inputMode="numeric"
          aria-label={t("repsAria", { name })}
          placeholder={t("repsPlaceholder")}
          value={row.targetReps ?? ""}
          onChange={(e) => onRepsChange(sanitizeCount(e.target.value, MAX_TEMPLATE_REPS))}
          data-testid="template-reps"
        />
      )}

      <IconButton icon="close" label={t("removeExerciseAria")} size={32} onClick={onRemove} />
    </div>
  );
}
