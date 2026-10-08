"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button, Drawer, TextField } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { trainerApi } from "../api";
import { goalToInput } from "../nutritionGoalsEditor";
import { isValidStepGoalInput, parseStepGoalInput } from "../stepGoalEditor";

/**
 * "Cél módosítása" (LIF-105): the trainer sets one client's daily step goal. A single field; empty clears the goal, zero
 * and anything that is not a whole number are flagged and block the save. The client is told by push when it really
 * changed, and the goal rides in the client summary, so saving refreshes that list.
 */
export function StepGoalDrawer({ clientId, goal, onClose }: { clientId: number; goal: number | null; onClose: () => void }) {
  const t = useTranslations("admin.clientDetail");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const initial = goalToInput(goal);
  const [draft, setDraft] = useState(initial);
  const valid = isValidStepGoalInput(draft);

  const save = useMutation({
    mutationFn: (value: number | null) => trainerApi.updateClientStepGoal(clientId, value),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerClients.all() });
      show(t("stepGoalUpdated"));
      onClose();
    },
    onError: () => show(t("stepGoalSaveFailed"), "error"),
  });

  return (
    <Drawer
      open
      onClose={onClose}
      width={480}
      title={t("stepGoalTitle")}
      isDirty={draft !== initial}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>{common("cancel")}</Button>
          <Button disabled={!valid || save.isPending} onClick={() => save.mutate(parseStepGoalInput(draft))}>
            {save.isPending ? common("saving") : t("goalsSave")}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-5">
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("stepGoalHint")}</p>
        <TextField
          label={t("stepGoalLabel")}
          inputMode="numeric"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          error={valid ? undefined : t("stepGoalInvalid")}
          hint={t("stepGoalUnit")}
        />
      </div>
    </Drawer>
  );
}
