"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { ProgramGridEditor } from "@/features/trainer/components/ProgramGridEditor";
import type { ProgramRequest } from "@/features/trainer/types";

export default function NewProgramPage() {
  const t = useTranslations("admin.programs");
  const router = useRouter();
  const queryClient = useQueryClient();
  const { show } = useToast();

  const createMutation = useMutation({
    mutationFn: (body: ProgramRequest) => trainerApi.createProgram(body),
    onSuccess: (program) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerPrograms.all() });
      show(t("created"), "success");
      router.push(`/admin/programs/${program.id}`);
    },
    onError: () => show(t("createFailed"), "error"),
  });

  return (
    <div className="flex flex-col gap-5">
      <ProgramGridEditor
        initialName={t("newProgramName")}
        initialWeeksCount={4}
        initialWorkouts={[]}
        saving={createMutation.isPending}
        saveLabel={t("save")}
        savingLabel={t("saving")}
        onSave={(data) => createMutation.mutateAsync(data)}
      />
    </div>
  );
}
