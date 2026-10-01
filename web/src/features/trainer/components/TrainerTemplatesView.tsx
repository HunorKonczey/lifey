"use client";

import { useState } from "react";
import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Avatar, Button, Card, ConfirmModal, DataTable, Icon, colorForSeed, type DataTableColumn } from "@/components/ds";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { exerciseApi, templateApi, workoutSessionApi } from "@/features/workouts/api";
import { TemplateEditorPanel } from "@/features/workouts/components/TemplateEditorPanel";
import { pickerTemplates } from "@/features/workouts/templatePicker";
import type { WorkoutTemplateResponse } from "@/features/workouts/types";
import { queryKeys } from "@/lib/api/queryKeys";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useToast } from "@/lib/hooks/useToast";
import { trainerApi } from "../api";
import { templateTags, templateUsers, type TemplateUser } from "../templateUsage";

interface Row {
  template: WorkoutTemplateResponse;
  exerciseCount: number;
  minutes: number;
  tags: string[];
  users: TemplateUser[];
}

interface Props {
  onAssign: (template: WorkoutTemplateResponse) => void;
  onSchedule: (template: WorkoutTemplateResponse) => void;
}

/**
 * The trainer's templates (W9-A): a sortable table — name with its muscle-group tags, exercises, time, the clients
 * that have it assigned — and the editor in a 520 px panel on the right (a drawer below 1280 px) that says how many
 * clients' future workouts a save reaches. "⋯" has Szerkesztés · Duplikálás · Kiosztás · Ütemezés · Törlés….
 * Switching rows or closing while the editor has unsaved changes asks first.
 */
export function TrainerTemplatesView({ onAssign, onSchedule }: Props) {
  const t = useTranslations("workouts");
  const admin = useTranslations("admin.assignDrawer");
  const schedule = useTranslations("admin.schedule");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const sidePanel = useMediaQuery("(min-width: 1280px)");
  const [search, setSearch] = useState("");
  const [selectedId, setSelectedId] = useState<number | "new" | null>(null);
  const [editorDirty, setEditorDirty] = useState(false);
  /** A row (or null = close) the trainer asked for while the editor had unsaved changes. */
  const [guarded, setGuarded] = useState<{ to: number | "new" | null } | null>(null);
  const [deleting, setDeleting] = useState<WorkoutTemplateResponse | null>(null);

  const templatesQ = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });
  const { data: exercises } = useQuery({ queryKey: queryKeys.exercises.all(), queryFn: exerciseApi.list });
  const { data: sessions } = useQuery({ queryKey: queryKeys.workoutSessions.all(), queryFn: workoutSessionApi.list });
  const { data: clients } = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });

  const templates = templatesQ.data ?? [];
  const assigned = useQueries({
    queries: templates.map((tpl) => ({
      queryKey: queryKeys.trainerAssignments.assignedClients("TEMPLATE", tpl.id),
      queryFn: () => trainerApi.assignedClientIds("TEMPLATE", tpl.id),
    })),
  });

  const sessionsDesc = (sessions ?? []).slice().sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());
  const picker = pickerTemplates(templates, sessionsDesc, null, new Date(), false);
  const rows: Row[] = picker.map((item, i) => ({
    template: item.template,
    exerciseCount: item.exerciseCount,
    minutes: item.estimatedMinutes,
    tags: templateTags(item.template, exercises ?? []),
    users: templateUsers(assigned[i]?.data, clients ?? []),
  }));
  const q = search.trim().toLowerCase();
  const visible = q ? rows.filter((r) => r.template.name.toLowerCase().includes(q)) : rows;
  const inUse = rows.filter((r) => r.users.length > 0).length;
  const selected = typeof selectedId === "number" ? rows.find((r) => r.template.id === selectedId) ?? null : null;

  const duplicateMutation = useMutation({
    mutationFn: (tpl: WorkoutTemplateResponse) =>
      templateApi.create({ name: t("copyOf", { name: tpl.name }), exercises: tpl.exercises.map((e) => ({ exerciseId: e.exerciseId, targetSets: e.targetSets })) }),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutTemplates.all() });
      show(t("templateDuplicated"), "success");
      setSelectedId(created.id);
    },
    onError: () => show(t("duplicateTemplateFailed"), "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: (tpl: WorkoutTemplateResponse) => templateApi.delete(tpl.id),
    onSuccess: (_, tpl) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutTemplates.all() });
      show(t("templateDeleted"), "success");
      if (selectedId === tpl.id) closeNow();
      setDeleting(null);
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  const closeNow = () => {
    setSelectedId(null);
    setEditorDirty(false);
  };
  /** Moves the panel to another row / closes it — asking first when the editor has unsaved changes. */
  const goTo = (to: number | "new" | null) => {
    if (to === selectedId) return;
    if (editorDirty && selectedId != null) {
      setGuarded({ to });
      return;
    }
    setEditorDirty(false);
    setSelectedId(to);
  };

  const columns: DataTableColumn<Row>[] = [
    {
      key: "name",
      header: t("colTemplateName"),
      sort: (r) => r.template.name,
      render: (r) => (
        <span className="flex min-w-0 items-center gap-3">
          <Icon name="list_alt" size={20} fill={1} color="var(--role)" />
          <span className="min-w-0">
            <span className="block truncate" style={{ fontWeight: 700 }}>{r.template.name}</span>
            {r.tags.length > 0 && (
              <span className="type-body-s block truncate" style={{ color: "var(--text-3)" }}>
                {r.tags.map((g) => t(`muscleGroups.${g}`)).join(" · ")}
              </span>
            )}
          </span>
        </span>
      ),
    },
    { key: "exercises", header: t("colTemplateExercises"), align: "right", sort: (r) => r.exerciseCount, render: (r) => <span className="num">{r.exerciseCount}</span> },
    { key: "time", header: t("colTemplateTime"), align: "right", sort: (r) => r.minutes, render: (r) => <span className="num">{t("templateMinutes", { minutes: r.minutes })}</span> },
    {
      key: "users",
      header: t("colTemplateUsedBy"),
      sort: (r) => r.users.length,
      render: (r) =>
        r.users.length === 0 ? (
          <span className="type-body-s" style={{ color: "var(--text-3)" }}>{t("usedByNobody")}</span>
        ) : (
          <span className="flex items-center gap-2">
            <span className="flex -space-x-2" aria-hidden>
              {r.users.slice(0, 3).map((u) => (
                <span key={u.clientId} className="rounded-full" style={{ boxShadow: "0 0 0 2px var(--card)" }}>
                  <Avatar name={u.name} email={u.email} size={24} color={colorForSeed(String(u.clientId))} />
                </span>
              ))}
            </span>
            <span className="type-body-s" style={{ color: "var(--text-2)" }}>{t("usedByClients", { count: r.users.length })}</span>
          </span>
        ),
    },
  ];

  const editor =
    selectedId != null ? (
      <TemplateEditorPanel
        key={selectedId}
        template={selected?.template ?? null}
        exercises={exercises ?? []}
        bare={!sidePanel}
        onDirtyChange={setEditorDirty}
        onSaved={(id) => setSelectedId(id)}
        onDeleted={closeNow}
        trainer={{ clientCount: selected?.users.length ?? 0, onClose: () => goTo(null) }}
      />
    ) : null;

  const list = templatesQ.isLoading ? (
    <Skeleton variant="table" />
  ) : templatesQ.isError ? (
    <ErrorState onRetry={templatesQ.refetch} />
  ) : templates.length === 0 ? (
    <EmptyState icon="list_alt" title={t("noTemplates")} body={t("createTemplate")} />
  ) : (
    <DataTable
      aria-label={t("templates")}
      columns={columns}
      rows={visible}
      rowKey={(r) => r.template.id}
      selectedKey={selectedId}
      pageSize={20}
      search={{ value: search, onChange: setSearch, placeholder: t("searchOwnTemplates") }}
      onRowOpen={(r) => goTo(r.template.id)}
      rowMenuLabel={(r) => t("templateRowMenuAria", { name: r.template.name })}
      rowMenu={(r) => [
        { label: t("editTemplate"), icon: "edit", onSelect: () => goTo(r.template.id) },
        { label: t("duplicateTemplateAria"), icon: "content_copy", onSelect: () => duplicateMutation.mutate(r.template) },
        { label: admin("assignAction"), icon: "person_add", onSelect: () => onAssign(r.template) },
        { label: schedule("scheduleForClientAria"), icon: "calendar_month", onSelect: () => onSchedule(r.template) },
        { label: common("delete"), icon: "delete", destructive: true, onSelect: () => setDeleting(r.template) },
      ]}
      renderCardRow={(r) => ({
        title: r.template.name,
        meta: t("pickerMeta", { exercises: r.exerciseCount, minutes: r.minutes }),
        value: r.users.length > 0 ? t("usedByClients", { count: r.users.length }) : undefined,
      })}
    />
  );

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="type-body" style={{ color: "var(--text-2)" }} data-testid="templates-subtitle">
          {t("trainerTemplatesSubtitle", { count: templates.length, used: inUse })}
        </p>
        <Button onClick={() => goTo("new")} data-testid="new-template-cta">
          <Icon name="add" size={20} />
          {t("newTemplate")}
        </Button>
      </div>

      <div className={sidePanel ? "grid items-start gap-6" : undefined} style={sidePanel ? { gridTemplateColumns: "minmax(0, 1fr) 520px" } : undefined}>
        <div className="min-w-0">{list}</div>

        {sidePanel && editor && (
          <aside className="sticky top-4" aria-label={t("templatePanelAria")}>
            <Card>{editor}</Card>
          </aside>
        )}
        {!sidePanel && editor && (
          <Drawer open onClose={() => goTo(null)} width={520} title={selected ? t("editTemplate") : t("newTemplate")} isDirty={editorDirty}>
            {editor}
          </Drawer>
        )}
      </div>

      <ConfirmModal
        open={guarded !== null}
        onClose={() => setGuarded(null)}
        onConfirm={() => {
          const to = guarded?.to ?? null;
          setGuarded(null);
          setEditorDirty(false);
          setSelectedId(to);
        }}
        icon="edit_off"
        destructive={false}
        tint="var(--primary)"
        title={t("unsavedGuardTitle")}
        body={t("unsavedGuardBody")}
        cancelLabel={t("unsavedGuardStay")}
        confirmLabel={t("unsavedGuardLeave")}
      />
      <ConfirmModal
        open={deleting !== null}
        onClose={() => setDeleting(null)}
        onConfirm={() => deleting && deleteMutation.mutate(deleting)}
        icon="delete"
        title={t("deleteTemplateTitle", { name: deleting?.name ?? "" })}
        body={t("deleteTemplateBody")}
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />
    </div>
  );
}
