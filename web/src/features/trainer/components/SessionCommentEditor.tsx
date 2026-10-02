"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button, Card, ConfirmModal, Icon, TextArea } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import type { WorkoutSessionResponse } from "@/features/workouts/types";
import { trainerApi } from "../api";
import { isCommentSaveable, MAX_COMMENT_LENGTH, trimCommentForSave } from "../sessionComment";

/**
 * The trainer's single comment on a session (docs/31-session-feedback-loop-plan.md), now inside the session drawer: the
 * client's own feedback note above it for context, then either "Megjegyzés hozzáadása", the composer, or the saved
 * comment with edit and delete (delete behind a confirmation). Same endpoints and rules as before.
 */
export function SessionCommentEditor({ clientId, session }: { clientId: number; session: WorkoutSessionResponse }) {
  const t = useTranslations("admin.clientDetail");
  const common = useTranslations("common");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [composing, setComposing] = useState(false);
  const [draft, setDraft] = useState("");
  const [confirmingDelete, setConfirmingDelete] = useState(false);

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["trainer-client-data", clientId, "sessions"] });

  const save = useMutation({
    mutationFn: (comment: string) => trainerApi.putSessionComment(clientId, session.id, comment),
    onSuccess: () => {
      invalidate();
      setComposing(false);
    },
    onError: () => show(t("commentSaveFailed"), "error"),
  });
  const remove = useMutation({
    mutationFn: () => trainerApi.deleteSessionComment(clientId, session.id),
    onSuccess: () => {
      invalidate();
      setConfirmingDelete(false);
    },
    onError: () => show(t("commentDeleteFailed"), "error"),
  });

  const startComposing = () => {
    setDraft(session.trainerComment ?? "");
    setComposing(true);
  };

  return (
    <section className="flex flex-col gap-3" aria-label={t("commentLabel")}>
      {session.feedbackNote && (
        <Card variant="nested">
          <p className="type-label" style={{ color: "var(--text-3)" }}>{t("clientNote")}</p>
          <p className="type-body mt-1" style={{ fontStyle: "italic" }}>“{session.feedbackNote}”</p>
        </Card>
      )}

      {composing ? (
        <div className="flex flex-col gap-3">
          <TextArea
            label={t("commentLabel")}
            placeholder={t("commentPlaceholder")}
            value={draft}
            maxLength={MAX_COMMENT_LENGTH}
            rows={4}
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
      ) : session.trainerComment ? (
        <Card variant="nested" className="flex flex-col gap-2" style={{ background: "color-mix(in srgb, var(--role) 14%, transparent)" }}>
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
          <p className="type-body">{session.trainerComment}</p>
          {session.trainerCommentAt && (
            <p className="type-body-s" style={{ color: "var(--text-3)" }}>
              {t("commentedAt", { time: fmt.relative(new Date(session.trainerCommentAt), new Date()) })}
            </p>
          )}
        </Card>
      ) : (
        <Button variant="tonal" className="self-start" onClick={startComposing}>
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
        body={t("commentDeleteConfirmBody")}
        cancelLabel={t("commentDeleteCancel")}
        confirmLabel={t("commentDeleteConfirm")}
      />
    </section>
  );
}
