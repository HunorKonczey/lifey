"use client";

import { useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { ProgramGridEditor } from "@/features/trainer/components/ProgramGridEditor";
import { AssignProgramDrawer } from "@/features/trainer/components/AssignProgramDrawer";
import type { ProgramRequest } from "@/features/trainer/types";

export default function EditProgramPage() {
  const t = useTranslations("admin.programs");
  const params = useParams<{ programId: string }>();
  const programId = Number(params.programId);
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [assignDrawerOpen, setAssignDrawerOpen] = useState(false);

  const { data: program, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerPrograms.detail(programId),
    queryFn: () => trainerApi.program(programId),
  });

  const updateMutation = useMutation({
    mutationFn: (body: ProgramRequest) => trainerApi.updateProgram(programId, body),
    onSuccess: (updated) => {
      queryClient.setQueryData(queryKeys.trainerPrograms.detail(programId), updated);
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerPrograms.all() });
      show(t("updated"), "success");
    },
    onError: () => show(t("updateFailed"), "error"),
  });

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <Link href="/admin/programs" className="flex items-center gap-1.5 text-[13px] font-semibold w-fit" style={{ color: "var(--on-surface-variant)" }}>
          <span className="material-symbols-rounded text-lg">arrow_back</span>
          {t("backToList")}
        </Link>
        {program && (
          <button
            type="button"
            onClick={() => setAssignDrawerOpen(true)}
            data-testid="program-assign-button"
            className="flex items-center gap-1.5 rounded-2xl px-4 py-2 text-[13px] font-bold"
            style={{ background: "var(--surface-container)", color: "var(--on-surface)" }}
          >
            <span className="material-symbols-rounded text-lg">person_add</span>
            {t("assignAction")}
          </button>
        )}
      </div>

      {isLoading ? (
        <Skeleton variant="card" />
      ) : isError || !program ? (
        <ErrorState onRetry={() => refetch()} />
      ) : (
        <ProgramGridEditor
          initialName={program.name}
          initialWeeksCount={program.weeksCount}
          initialWorkouts={program.workouts.map((w) => ({
            weekNumber: w.weekNumber,
            dayOfWeek: w.dayOfWeek,
            templateId: w.templateId,
            timeOfDay: w.timeOfDay,
            note: w.note,
          }))}
          saving={updateMutation.isPending}
          saveLabel={t("save")}
          savingLabel={t("saving")}
          onSave={(data) => updateMutation.mutate(data)}
        />
      )}

      {assignDrawerOpen && program && (
        <AssignProgramDrawer
          programId={program.id}
          programName={program.name}
          onClose={() => setAssignDrawerOpen(false)}
        />
      )}
    </div>
  );
}
