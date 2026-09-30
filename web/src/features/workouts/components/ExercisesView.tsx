"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, ConfirmModal, DataTable, Icon } from "@/components/ds";
import type { DataTableColumn } from "@/components/ds";
import type { MenuItemDef } from "@/components/ds/Menu";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { queryKeys } from "@/lib/api/queryKeys";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useToast, TOAST_DURATION_MS } from "@/lib/hooks/useToast";
import { useUndoableDelete } from "@/lib/hooks/useUndoableDelete";
import { matchesFoodSearch as matchesName } from "@/features/nutrition/foodsTable";
import { exerciseApi } from "../api";
import { exerciseIcon, formatRest, muscleGroupColor } from "../exerciseUi";
import { MUSCLE_GROUPS, type ExerciseRequest, type ExerciseResponse } from "../types";
import { ExerciseEditorPanel } from "./ExerciseEditorPanel";

/**
 * The exercises tab (W3.12): the DS `DataTable` — sortable name / muscle group / equipment / rest columns, a
 * search box (`/`), muscle-group filter chips, "＋ Új gyakorlat" and a "⋯" per row (Edit, Delete… with undo) —
 * and the editor in a side panel from 1280 px, a drawer below. Rows are cards on a phone.
 */
export function ExercisesView() {
  const t = useTranslations("workouts");
  const tm = useTranslations("workouts.muscleGroups");
  const te = useTranslations("workouts.equipmentTypes");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const undoableDelete = useUndoableDelete();
  const sidePanel = useMediaQuery("(min-width: 1280px)");
  const [categoryFilter, setCategoryFilter] = useState<string>("ALL");
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<{ exercise: ExerciseResponse | null; key: string } | null>(null);
  const [editorDirty, setEditorDirty] = useState(false);
  const [deleting, setDeleting] = useState<ExerciseResponse | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({ queryKey: queryKeys.exercises.all(), queryFn: exerciseApi.list });

  const closeEditor = () => {
    setEditing(null);
    setEditorDirty(false);
  };

  const saveMutation = useMutation({
    mutationFn: ({ exercise, request }: { exercise: ExerciseResponse | null; request: ExerciseRequest }) =>
      exercise ? exerciseApi.update(exercise.id, request) : exerciseApi.create(request),
    onSuccess: (_saved, { exercise }) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.exercises.all() });
      show(exercise ? t("exerciseUpdated") : t("exerciseCreated"), "success");
      closeEditor();
    },
    onError: () => show(t("saveExerciseFailed"), "error"),
  });

  const setCached = (update: (list: ExerciseResponse[]) => ExerciseResponse[]) =>
    queryClient.setQueryData<ExerciseResponse[]>(queryKeys.exercises.all(), (old) => update(old ?? []));

  // Delete = confirm → the row leaves the table and a toast offers Undo; the DELETE goes out when the window closes.
  const deleteExercise = (exercise: ExerciseResponse) => {
    if (editing?.exercise?.id === exercise.id) closeEditor();
    undoableDelete({
      message: t("exerciseDeletedUndo", { name: exercise.name }),
      path: `/exercises/${exercise.id}`,
      remove: () => setCached((list) => list.filter((e) => e.id !== exercise.id)),
      restore: () => setCached((list) => (list.some((e) => e.id === exercise.id) ? list : [...list, exercise].sort((a, b) => a.name.localeCompare(b.name)))),
      errorMessage: t("deleteExerciseFailed"),
    });
  };

  if (isLoading) return <Skeleton variant="table" />;
  if (isError) return <ErrorState onRetry={refetch} />;

  const all = data ?? [];
  const presentCategories = MUSCLE_GROUPS.filter((c) => all.some((e) => e.category === c));
  const rows = all.filter((e) => (categoryFilter === "ALL" || e.category === categoryFilter) && (search.trim() === "" || matchesName(e.name, search)));
  const label = (e: ExerciseResponse) => (e.category ? tm(e.category) : "");

  const open = (exercise: ExerciseResponse | null) => setEditing({ exercise, key: exercise ? `ex:${exercise.id}` : `new:${Date.now()}` });

  const columns: DataTableColumn<ExerciseResponse>[] = [
    {
      key: "name",
      header: t("colExercise"),
      sort: (e) => e.name.toLocaleLowerCase(),
      render: (e) => (
        <span className="flex items-center gap-3">
          <span
            className="flex flex-none items-center justify-center"
            style={{ width: 32, height: 32, borderRadius: 10, background: `color-mix(in srgb, ${muscleGroupColor(e.category)} var(--chip-tint), transparent)`, color: muscleGroupColor(e.category) }}
          >
            <Icon name={exerciseIcon(e)} size={18} />
          </span>
          <span style={{ fontWeight: 700 }}>{e.name}</span>
        </span>
      ),
    },
    {
      key: "category",
      header: t("category"),
      sort: (e) => label(e).toLocaleLowerCase() || "￿",
      render: (e) =>
        e.category ? (
          <span
            className="type-label inline-block rounded-[var(--r-pill)] px-2.5 py-1"
            style={{ color: muscleGroupColor(e.category), background: `color-mix(in srgb, ${muscleGroupColor(e.category)} var(--chip-tint), transparent)` }}
          >
            {tm(e.category)}
          </span>
        ) : (
          <span style={{ color: "var(--text-3)" }}>—</span>
        ),
    },
    {
      key: "equipment",
      header: t("equipment"),
      sort: (e) => (e.equipment ? te(e.equipment).toLocaleLowerCase() : "￿"),
      render: (e) => (e.equipment ? te(e.equipment) : <span style={{ color: "var(--text-3)" }}>—</span>),
    },
    {
      key: "rest",
      header: t("colRest"),
      align: "right",
      // No own rest sorts below every set one when descending.
      sort: (e) => e.defaultRestSeconds ?? -1,
      render: (e) => {
        const rest = formatRest(e.defaultRestSeconds);
        return rest ? <span className="tabular">{rest}</span> : <span style={{ color: "var(--text-3)" }}>{t("restDefault")}</span>;
      },
    },
  ];

  const rowMenu = (e: ExerciseResponse): MenuItemDef[] => [
    { label: t("menuEdit"), icon: "edit", onSelect: () => open(e) },
    { label: t("menuDelete"), icon: "delete", destructive: true, onSelect: () => setDeleting(e) },
  ];

  const chips = (
    <div role="group" aria-label={t("muscleFilterAria")} className="flex flex-wrap gap-2">
      {["ALL", ...presentCategories].map((c) => {
        const on = categoryFilter === c;
        return (
          <button
            key={c}
            type="button"
            aria-pressed={on}
            onClick={() => setCategoryFilter(c)}
            className="lifey-button type-body-s"
            style={{ height: 30, padding: "0 14px", borderRadius: "var(--r-pill)", fontWeight: 700, background: on ? "var(--primary)" : "var(--nested)", color: on ? "var(--on-primary)" : "var(--text-2)" }}
          >
            {c === "ALL" ? t("allFilter") : tm(c)}
          </button>
        );
      })}
    </div>
  );

  const editor = editing && (
    <ExerciseEditorPanel
      key={editing.key}
      exercise={editing.exercise}
      pending={saveMutation.isPending}
      bare={!sidePanel}
      onDirtyChange={setEditorDirty}
      onSave={(request) => saveMutation.mutate({ exercise: editing.exercise, request })}
      onCancel={closeEditor}
    />
  );

  return (
    <div className="flex flex-col gap-6 xl:flex-row xl:items-start">
      {editing && sidePanel && <div className="order-last sticky top-6 w-[380px] shrink-0 rounded-[var(--r-card)] p-5" style={{ background: "var(--card)", boxShadow: "var(--e1)" }}>{editor}</div>}

      <div className="min-w-0 flex-1" data-testid="exercises-table">
        {all.length === 0 ? (
          <EmptyState
            icon="fitness_center"
            title={t("noExercisesYet")}
            body={t("addExercisesBody")}
            action={
              <Button onClick={() => open(null)}>
                <Icon name="add" size={20} />
                {t("newExercise")}
              </Button>
            }
          />
        ) : (
          <div className="flex flex-col gap-4">
            <DataTable
              aria-label={t("exercisesTableAria")}
              columns={columns}
              rows={rows}
              rowKey={(e) => e.id}
              selectedKey={editing?.exercise?.id ?? null}
              onRowOpen={(e) => open(e)}
              rowMenu={rowMenu}
              rowMenuLabel={(e) => t("rowMenuLabel", { name: e.name })}
              pageSize={15}
              search={{ value: search, onChange: setSearch, placeholder: t("searchExercisesPlaceholder") }}
              filters={chips}
              totalLabel={(n) => t("totalExercises", { count: n })}
              action={
                <Button onClick={() => open(null)}>
                  <Icon name="add" size={20} />
                  {t("newExercise")}
                </Button>
              }
              renderCardRow={(e) => ({
                title: e.name,
                meta: [e.category ? tm(e.category) : null, e.equipment ? te(e.equipment) : null].filter(Boolean).join(" · ") || undefined,
                value: formatRest(e.defaultRestSeconds) ?? undefined,
              })}
            />
            {rows.length === 0 && <EmptyState compact icon="fitness_center" title={t("noMatch")} body={t("tryDifferentSearch")} />}
          </div>
        )}
      </div>

      {editing && !sidePanel && (
        <Drawer open onClose={closeEditor} width={480} title={editing.exercise ? t("editExercise") : t("newExerciseTitle")} isDirty={editorDirty}>
          {editor}
        </Drawer>
      )}

      <ConfirmModal
        open={deleting != null}
        onClose={() => setDeleting(null)}
        onConfirm={() => {
          if (deleting) deleteExercise(deleting);
          setDeleting(null);
        }}
        icon="delete"
        title={deleting ? t("deleteExerciseTitle", { name: deleting.name }) : ""}
        body={deleting ? t("deleteExerciseBody", { seconds: TOAST_DURATION_MS / 1000 }) : ""}
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />
    </div>
  );
}
