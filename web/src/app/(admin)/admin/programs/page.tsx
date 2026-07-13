"use client";

import { useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { AssignProgramDrawer } from "@/features/trainer/components/AssignProgramDrawer";
import { useToast } from "@/lib/hooks/useToast";
import type { ProgramSummaryResponse } from "@/features/trainer/types";

export default function AdminProgramsPage() {
  const t = useTranslations("admin.programs");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [deleteTarget, setDeleteTarget] = useState<ProgramSummaryResponse | null>(null);
  const [assignTarget, setAssignTarget] = useState<ProgramSummaryResponse | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerPrograms.all(),
    queryFn: trainerApi.programs,
  });

  const deleteMutation = useMutation({
    mutationFn: (programId: number) => trainerApi.deleteProgram(programId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerPrograms.all() });
      show(t("deleted"), "success");
      setDeleteTarget(null);
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  if (isLoading) return <Skeleton variant="table" />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const programs = data ?? [];

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
          {t("title")}
        </p>
        <Link
          href="/admin/programs/new"
          data-testid="new-program-cta"
          className="h-10 px-4 rounded-2xl flex items-center gap-1.5 text-[13px] font-extrabold"
          style={{ background: "var(--tertiary)", color: "#161611" }}
        >
          <span className="material-symbols-rounded text-lg">add</span>
          {t("newProgram")}
        </Link>
      </div>

      {programs.length === 0 ? (
        <EmptyState icon="event_repeat" title={t("emptyTitle")} body={t("emptyBody")} />
      ) : (
        <div className="grid gap-3" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(260px, 1fr))" }}>
          {programs.map((program) => (
            <div
              key={program.id}
              data-testid="program-card"
              className="flex flex-col gap-3 rounded-[var(--r-lg)] p-4"
              style={{ background: "var(--surface)" }}
            >
              <div className="flex items-start justify-between gap-2">
                <Link href={`/admin/programs/${program.id}`} className="flex-1 min-w-0">
                  <p className="text-[14.5px] font-extrabold truncate" style={{ color: "var(--on-surface)" }}>
                    {program.name}
                  </p>
                </Link>
                <button
                  type="button"
                  onClick={() => setDeleteTarget(program)}
                  data-testid="program-delete-button"
                  className="p-1 rounded-[var(--r-sm)] shrink-0"
                  style={{ color: "var(--on-surface-variant)" }}
                  aria-label={t("delete")}
                >
                  <span className="material-symbols-rounded text-xl">delete</span>
                </button>
              </div>
              <div className="flex flex-wrap gap-1.5">
                <span
                  className="text-[11px] font-bold px-2.5 py-1 rounded-full"
                  style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
                >
                  {t("weeksCount", { count: program.weeksCount })}
                </span>
                <span
                  className="text-[11px] font-bold px-2.5 py-1 rounded-full"
                  style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
                >
                  {t("slotsPerWeek", { count: program.slotsPerWeek })}
                </span>
              </div>
              <p className="text-[11.5px]" style={{ color: "var(--on-surface-variant)" }}>
                {t("activeAssignments", { count: program.activeAssignmentCount })}
              </p>
              <button
                type="button"
                onClick={() => setAssignTarget(program)}
                data-testid="program-assign-button"
                className="flex items-center justify-center gap-1.5 rounded-xl h-9 text-[12.5px] font-bold"
                style={{ background: "var(--surface-container)", color: "var(--on-surface)" }}
              >
                <span className="material-symbols-rounded text-base">person_add</span>
                {t("assignAction")}
              </button>
            </div>
          ))}
        </div>
      )}

      <ConfirmDialog
        open={deleteTarget != null}
        title={t("deleteConfirmTitle")}
        body={t("deleteConfirmBody")}
        confirmLabel={t("deleteConfirm")}
        confirming={deleteMutation.isPending}
        onConfirm={() => deleteTarget && deleteMutation.mutate(deleteTarget.id)}
        onCancel={() => setDeleteTarget(null)}
      />

      {assignTarget && (
        <AssignProgramDrawer
          programId={assignTarget.id}
          programName={assignTarget.name}
          onClose={() => setAssignTarget(null)}
        />
      )}
    </div>
  );
}
