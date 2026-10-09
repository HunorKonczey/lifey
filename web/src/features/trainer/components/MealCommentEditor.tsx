"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button, ConfirmModal, Icon, TextArea } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import type { MealResponse } from "@/features/nutrition/types";
import { trainerApi } from "../api";
import { isCommentSaveable, MAX_COMMENT_LENGTH, trimCommentForSave } from "../sessionComment";

/**
 * The trainer's single comment on one of a client's meals (LIF-144), under the meal on the client's nutrition tab: an
 * "add comment" button, the composer, or the saved comment with edit and delete (delete behind a confirmation). The same
 * rules and wording as the session comment ({@link ../components/SessionCommentEditor}); the client is pushed on the
 * first comment only, which the toast says.
 */
export function MealCommentEditor({ clientId, meal, date }: { clientId: number; meal: MealResponse; date: string }) {
  const t = useTranslations("admin.clientDetail");
  const common = useTranslations("common");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [composing, setComposing] = useState(false);
  const [draft, setDraft] = useState("");
  const [confirmingDelete, setConfirmingDelete] = useState(false);

  const invalidate = () => queryClient.invalidateQueries({ queryKey: queryKeys.trainerClientData.meals(clientId, date) });

  const save = useMutation({
    mutationFn: (comment: string) => trainerApi.putMealComment(clientId, meal.id, comment),
    onSuccess: () => {
      // The client is pushed on the first comment only, so only then is it said.
      show(meal.trainerComment ? t("mealCommentSaved") : t("mealCommentSavedNotified"));
      invalidate();
      setComposing(false);
    },
    onError: () => show(t("commentSaveFailed"), "error"),
  });
  const remove = useMutation({
    mutationFn: () => trainerApi.deleteMealComment(clientId, meal.id),
    onSuccess: () => {
      invalidate();
      setConfirmingDelete(false);
    },
    onError: () => show(t("commentDeleteFailed"), "error"),
  });

  const startComposing = () => {
    setDraft(meal.trainerComment ?? "");
    setComposing(true);
  };

  return (
    <div data-testid="meal-comment-editor" className="mx-4 mb-4 mt-1 flex flex-col gap-3">
      {composing ? (
        <div className="flex flex-col gap-3">
          <TextArea
            label={t("commentLabel")}
            placeholder={t("mealCommentPlaceholder")}
            value={draft}
            maxLength={MAX_COMMENT_LENGTH}
            rows={3}
            autoFocus
            onChange={(e) => setDraft(e.target.value)}
            hint={`${draft.trim().length} / ${MAX_COMMENT_LENGTH}`}
          />
          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setComposing(false)}>{common("cancel")}</Button>
            <Button
              disabled={!isCommentSaveable(draft) || save.isPending}
              onClick={() => {
                const comment = trimCommentForSave(draft);
                if (comment) save.mutate(comment);
              }}
            >
              {save.isPending ? common("saving") : t("commentSave")}
            </Button>
          </div>
        </div>
      ) : meal.trainerComment ? (
        <div
          className="flex flex-col gap-2 p-3"
          style={{ borderRadius: "var(--r-control)", background: "color-mix(in srgb, var(--role) 14%, transparent)" }}
        >
          <div className="flex items-center justify-between gap-2">
            <p className="type-label" style={{ color: "var(--text-2)" }}>{t("commentLabel")}</p>
            <div className="flex items-center gap-1">
              <button type="button" onClick={startComposing} aria-label={t("commentEdit")} className="lifey-button inline-flex h-8 w-8 items-center justify-center" style={{ borderRadius: 10 }}>
                <Icon name="edit" size={18} />
              </button>
              <button type="button" onClick={() => setConfirmingDelete(true)} aria-label={t("commentDelete")} className="lifey-button inline-flex h-8 w-8 items-center justify-center" style={{ borderRadius: 10 }}>
                <Icon name="delete" size={18} />
              </button>
            </div>
          </div>
          <p className="type-body" data-testid="meal-comment-text" style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{meal.trainerComment}</p>
          {meal.trainerCommentAt && (
            <p className="type-body-s" style={{ color: "var(--text-3)" }}>
              {t("commentedAt", { time: fmt.relative(new Date(meal.trainerCommentAt), new Date()) })}
            </p>
          )}
        </div>
      ) : (
        <Button variant="tonal" className="self-start" onClick={startComposing} data-testid="meal-comment-add">
          <Icon name="add_comment" size={18} />
          {t("commentAdd")}
        </Button>
      )}

      <ConfirmModal
        open={confirmingDelete}
        onClose={() => setConfirmingDelete(false)}
        onConfirm={() => remove.mutate()}
        icon="delete"
        title={t("commentDeleteConfirmTitle")}
        body={t("mealCommentDeleteConfirmBody")}
        cancelLabel={t("commentDeleteCancel")}
        confirmLabel={t("commentDeleteConfirm")}
      />
    </div>
  );
}
