"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { Button, ConfirmModal, DataTable, Icon, type DataTableColumn } from "@/components/ds";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { AssignProgramDrawer } from "@/features/trainer/components/AssignProgramDrawer";
import { useToast } from "@/lib/hooks/useToast";
import type { ProgramSummaryResponse } from "@/features/trainer/types";

/**
 * The trainer's programs (W8.7) on the DS `DataTable`: name, weeks, workout days a week and how many clients are on it,
 * sortable, searchable (`/`), a row opens the editor and "⋯" has Szerkesztés · Duplikálás · Kiosztás · Törlés….
 */
export default function AdminProgramsPage() {
  const t = useTranslations("admin.programs");
  const router = useRouter();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [search, setSearch] = useState("");
  const [deleteTarget, setDeleteTarget] = useState<ProgramSummaryResponse | null>(null);
  const [assignTarget, setAssignTarget] = useState<ProgramSummaryResponse | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({ queryKey: queryKeys.trainerPrograms.all(), queryFn: trainerApi.programs });

  const deleteMutation = useMutation({
    mutationFn: (programId: number) => trainerApi.deleteProgram(programId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerPrograms.all() });
      show(t("deleted"), "success");
      setDeleteTarget(null);
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  // A copy is a new program with the same grid: read the original, post it under "<name> (másolat)".
  const duplicateMutation = useMutation({
    mutationFn: async (program: ProgramSummaryResponse) => {
      const full = await trainerApi.program(program.id);
      return trainerApi.createProgram({
        name: t("copyName", { name: full.name }),
        weeksCount: full.weeksCount,
        workouts: full.workouts.map((w) => ({ weekNumber: w.weekNumber, dayOfWeek: w.dayOfWeek, templateId: w.templateId, timeOfDay: w.timeOfDay, note: w.note })),
      });
    },
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerPrograms.all() });
      show(t("duplicated"), "success");
      router.push(`/admin/programs/${created.id}`);
    },
    onError: () => show(t("duplicateFailed"), "error"),
  });

  if (isLoading) return <Skeleton variant="table" />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const programs = data ?? [];
  const q = search.trim().toLowerCase();
  const rows = q ? programs.filter((p) => p.name.toLowerCase().includes(q)) : programs;

  const columns: DataTableColumn<ProgramSummaryResponse>[] = [
    {
      key: "name",
      header: t("colName"),
      sort: (p) => p.name,
      render: (p) => (
        <span className="flex items-center gap-3 min-w-0">
          <Icon name="event_repeat" size={20} fill={1} color="var(--role)" />
          <Link href={`/admin/programs/${p.id}`} className="truncate" style={{ fontWeight: 700 }} onClick={(e) => e.stopPropagation()}>{p.name}</Link>
        </span>
      ),
    },
    { key: "weeks", header: t("colWeeks"), align: "right", sort: (p) => p.weeksCount, render: (p) => <span className="num">{p.weeksCount}</span> },
    { key: "slots", header: t("colSlots"), align: "right", sort: (p) => p.slotsPerWeek, render: (p) => <span className="num">{p.slotsPerWeek}</span> },
    { key: "users", header: t("colUsers"), align: "right", sort: (p) => p.activeAssignmentCount, render: (p) => <span className="num">{p.activeAssignmentCount}</span> },
  ];

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="type-body" style={{ color: "var(--text-2)" }}>{t("listSubtitle", { count: programs.length })}</p>
        <Link href="/admin/programs/new" data-testid="new-program-cta">
          <Button>
            <Icon name="add" size={20} />
            {t("newProgram")}
          </Button>
        </Link>
      </div>

      {programs.length === 0 ? (
        <EmptyState icon="event_repeat" title={t("emptyTitle")} body={t("emptyBody")} />
      ) : (
        <DataTable
          aria-label={t("title")}
          columns={columns}
          rows={rows}
          rowKey={(p) => p.id}
          pageSize={20}
          search={{ value: search, onChange: setSearch, placeholder: t("searchProgramPlaceholder") }}
          totalLabel={(n) => t("listSubtitle", { count: n })}
          onRowOpen={(p) => router.push(`/admin/programs/${p.id}`)}
          rowMenuLabel={(p) => t("rowMenuAria", { name: p.name })}
          rowMenu={(p) => [
            { label: t("edit"), icon: "edit", onSelect: () => router.push(`/admin/programs/${p.id}`) },
            { label: t("duplicate"), icon: "content_copy", onSelect: () => duplicateMutation.mutate(p) },
            { label: t("assignAction"), icon: "person_add", onSelect: () => setAssignTarget(p) },
            { label: t("delete"), icon: "delete", destructive: true, onSelect: () => setDeleteTarget(p) },
          ]}
          renderCardRow={(p) => ({ title: p.name, meta: `${t("weeksCount", { count: p.weeksCount })} · ${t("slotsPerWeek", { count: p.slotsPerWeek })}`, value: t("activeAssignments", { count: p.activeAssignmentCount }) })}
        />
      )}

      <ConfirmModal
        open={deleteTarget != null}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteTarget && deleteMutation.mutate(deleteTarget.id)}
        icon="delete"
        title={t("deleteConfirmTitle")}
        body={t("deleteConfirmBody")}
        cancelLabel={t("cancel")}
        confirmLabel={t("deleteConfirm")}
      />

      {assignTarget && <AssignProgramDrawer programId={assignTarget.id} programName={assignTarget.name} onClose={() => setAssignTarget(null)} />}
    </div>
  );
}
