"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format, formatDistanceToNow } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { isCommentSaveable, trimCommentForSave } from "../sessionComment";
import { queryKeys } from "@/lib/api/queryKeys";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { useLocale } from "@/lib/hooks/useLocale";
import { useToast } from "@/lib/hooks/useToast";
import type { WorkoutSessionResponse } from "@/features/workouts/types";

const DATE_LOCALES = { en: enUS, hu } as const;

interface ClientWorkoutsTabProps {
  clientId: number;
  /* Set when arriving from the Schedule tab's "jump to session" — expands and scrolls to it once loaded. */
  focusSessionId?: number | null;
  onFocusHandled?: () => void;
}

export function ClientWorkoutsTab({ clientId, focusSessionId, onFocusHandled }: ClientWorkoutsTabProps) {
  const t = useTranslations("admin.clientDetail");
  const common = useTranslations("common");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const [page, setPage] = useState(0);
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const rowRefs = useRef<Record<number, HTMLDivElement | null>>({});

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerClientData.sessions(clientId, page, 15),
    queryFn: () => trainerApi.clientWorkoutSessions(clientId, page, 15),
  });

  // Adjusted during render (React's blessed pattern, see DatePicker's prevValue)
  // rather than in an effect, since it's a plain state derivation, not a side effect.
  const [consumedFocusSessionId, setConsumedFocusSessionId] = useState<number | null | undefined>(undefined);
  const focusTarget = focusSessionId != null && data?.content.some((s) => s.id === focusSessionId)
    ? focusSessionId
    : null;
  if (focusTarget != null && focusTarget !== consumedFocusSessionId) {
    setConsumedFocusSessionId(focusTarget);
    setExpandedId(focusTarget);
  }

  useEffect(() => {
    if (focusTarget == null) return;
    rowRefs.current[focusTarget]?.scrollIntoView({ behavior: "smooth", block: "center" });
    onFocusHandled?.();
  }, [focusTarget, onFocusHandled]);

  if (isLoading) return <Skeleton variant="table" />;
  if (isError) return <ErrorState onRetry={refetch} />;
  if (!data || data.content.length === 0) {
    return <EmptyState icon="fitness_center" title={t("noSessions")} />;
  }

  return (
    <div className="flex flex-col gap-3.5">
      <div className="flex flex-col gap-2">
        {data.content.map((s) => {
          const expanded = expandedId === s.id;
          const volume = s.sets.reduce((sum, set) => sum + set.reps * set.weight, 0);
          const durationMin = s.finishedAt
            ? Math.round((new Date(s.finishedAt).getTime() - new Date(s.startedAt).getTime()) / 60000)
            : null;
          return (
            <div
              key={s.id}
              ref={(el) => { rowRefs.current[s.id] = el; }}
              className="rounded-[var(--r-card)]"
              style={{ background: "var(--surface)", outline: focusSessionId === s.id ? "2px solid var(--tertiary)" : "none" }}
            >
              <button
                onClick={() => setExpandedId(expanded ? null : s.id)}
                className="w-full flex items-center gap-3.5 px-4 py-3.5 text-left"
              >
                <span className="material-symbols-rounded text-xl" style={{ color: "var(--on-surface-variant)" }}>
                  {expanded ? "expand_more" : "chevron_right"}
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold" style={{ color: "var(--on-surface)" }}>
                    {format(new Date(s.startedAt), "yyyy. MMM d. HH:mm", { locale: dateLocale })}
                  </p>
                  <p className="text-[11.5px] mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                    {t("sessionMeta", {
                      duration: durationMin ?? "—",
                      count: s.exercises.length,
                      volume: Math.round(volume).toLocaleString(),
                    })}
                  </p>
                </div>
                {s.rpe != null && (
                  <span
                    className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[11px] font-extrabold px-2.5 py-1.5 shrink-0"
                    style={{
                      background: "color-mix(in srgb, var(--secondary) 18%, transparent)",
                      color: "var(--secondary)",
                    }}
                  >
                    <span className="material-symbols-rounded text-sm">speed</span>
                    {t("sessionRpe", { rpe: s.rpe })}
                  </span>
                )}
                {s.templateName && (
                  <span
                    className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[11px] font-extrabold px-2.5 py-1.5 shrink-0"
                    style={{ background: "var(--tertiary-container)", color: "var(--on-tertiary-container)" }}
                  >
                    <span className="material-symbols-rounded text-sm">assignment</span>
                    {s.templateName}
                  </span>
                )}
              </button>
              {expanded && (
                <div className="px-4 pb-4 flex flex-col gap-2">
                  {s.feedbackNote && (
                    <p
                      className="text-[12.5px] italic px-3 py-2 rounded-2xl"
                      style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
                    >
                      “{s.feedbackNote}”
                    </p>
                  )}
                  <SessionCommentBlock clientId={clientId} session={s} dateLocale={dateLocale} />
                  {s.exercises.map((ex) => {
                    const exerciseSets = s.sets.filter((set) => set.exerciseId === ex.exerciseId);
                    return (
                      <div key={ex.exerciseId} className="rounded-2xl p-3" style={{ background: "var(--surface-container)" }}>
                        <p className="text-[13px] font-bold mb-1.5" style={{ color: "var(--on-surface)" }}>
                          {ex.exerciseName}
                        </p>
                        <div className="flex flex-wrap gap-2">
                          {exerciseSets.map((set, i) => (
                            <span
                              key={i}
                              className="text-xs tabular font-semibold px-2.5 py-1 rounded-lg"
                              style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
                            >
                              {set.reps} × {set.weight} kg
                            </span>
                          ))}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div className="flex items-center justify-center gap-1.5">
        <button
          onClick={() => setPage((p) => Math.max(0, p - 1))}
          disabled={data.number === 0}
          className="p-1.5 disabled:opacity-30"
          style={{ color: "var(--on-surface-variant)" }}
          aria-label={common("previousPage")}
        >
          <span className="material-symbols-rounded text-xl">chevron_left</span>
        </button>
        <span className="text-xs font-bold px-2" style={{ color: "var(--on-surface-variant)" }}>
          {data.number + 1} / {Math.max(1, data.totalPages)}
        </span>
        <button
          onClick={() => setPage((p) => (data.last ? p : p + 1))}
          disabled={data.last}
          className="p-1.5 disabled:opacity-30"
          style={{ color: "var(--on-surface-variant)" }}
          aria-label={common("nextPage")}
        >
          <span className="material-symbols-rounded text-xl">chevron_right</span>
        </button>
      </div>
    </div>
  );
}

interface SessionCommentBlockProps {
  clientId: number;
  session: WorkoutSessionResponse;
  dateLocale: (typeof DATE_LOCALES)[keyof typeof DATE_LOCALES];
}

/**
 * The trainer's single editable comment on a session (docs/31-session-feedback-loop-plan.md,
 * W2) — rendered right under the client's own feedback note, one level below it visually.
 */
function SessionCommentBlock({ clientId, session, dateLocale }: SessionCommentBlockProps) {
  const t = useTranslations("admin.clientDetail");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [composing, setComposing] = useState(false);
  const [draft, setDraft] = useState("");
  const [confirmingDelete, setConfirmingDelete] = useState(false);

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["trainer-client-data", clientId, "sessions"] });
  };

  const saveMutation = useMutation({
    mutationFn: (comment: string) => trainerApi.putSessionComment(clientId, session.id, comment),
    onSuccess: () => {
      invalidate();
      setComposing(false);
    },
    onError: () => show(t("commentSaveFailed"), "error"),
  });

  const deleteMutation = useMutation({
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

  if (composing) {
    return (
      <div className="rounded-2xl p-3 flex flex-col gap-2" style={{ background: "var(--surface-container)" }}>
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={t("commentPlaceholder")}
          rows={3}
          maxLength={2000}
          autoFocus
          className="w-full text-[13px] rounded-[var(--r-input)] px-3 py-2 resize-none"
          style={{ background: "var(--surface)", color: "var(--on-surface)", border: "1px solid var(--outline)" }}
        />
        <div className="flex items-center justify-between">
          <span className="text-[11px]" style={{ color: "var(--on-surface-variant)" }}>
            {draft.trim().length} / 2000
          </span>
          <div className="flex gap-2.5">
            <button
              onClick={() => setComposing(false)}
              className="text-sm font-bold px-3 py-1.5"
              style={{ color: "var(--on-surface-variant)" }}
            >
              {common("cancel")}
            </button>
            <button
              onClick={() => {
                const comment = trimCommentForSave(draft);
                if (comment) saveMutation.mutate(comment);
              }}
              disabled={!isCommentSaveable(draft) || saveMutation.isPending}
              className="rounded-xl px-4 py-1.5 text-sm font-extrabold disabled:opacity-60"
              style={{ background: "var(--primary)", color: "var(--on-primary)" }}
            >
              {saveMutation.isPending ? common("saving") : t("commentSave")}
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (!session.trainerComment) {
    return (
      <button
        onClick={startComposing}
        className="self-start text-[12.5px] font-bold px-3 py-1.5 rounded-full flex items-center gap-1.5"
        style={{ color: "var(--primary)", background: "color-mix(in srgb, var(--primary) 12%, transparent)" }}
      >
        <span className="material-symbols-rounded text-sm">add_comment</span>
        {t("commentAdd")}
      </button>
    );
  }

  return (
    <div className="rounded-2xl p-3 flex flex-col gap-1.5" style={{ background: "var(--tertiary-container)" }}>
      <div className="flex items-start justify-between gap-2">
        <p className="text-[11px] font-extrabold uppercase tracking-wide" style={{ color: "var(--on-tertiary-container)" }}>
          {t("commentLabel")}
        </p>
        <div className="flex items-center gap-1 shrink-0">
          <button onClick={startComposing} aria-label={t("commentEdit")} style={{ color: "var(--on-tertiary-container)" }}>
            <span className="material-symbols-rounded text-base">edit</span>
          </button>
          <button onClick={() => setConfirmingDelete(true)} aria-label={t("commentDelete")} style={{ color: "var(--on-tertiary-container)" }}>
            <span className="material-symbols-rounded text-base">delete</span>
          </button>
        </div>
      </div>
      <p className="text-[13px]" style={{ color: "var(--on-tertiary-container)" }}>
        {session.trainerComment}
      </p>
      {session.trainerCommentAt && (
        <p className="text-[11px]" style={{ color: "var(--on-tertiary-container)", opacity: 0.75 }}>
          {t("commentedAt", {
            time: formatDistanceToNow(new Date(session.trainerCommentAt), { addSuffix: true, locale: dateLocale }),
          })}
        </p>
      )}

      {confirmingDelete && (
        <div
          className="fixed inset-0 z-30 flex items-center justify-center p-4"
          style={{ background: "rgba(8,9,6,.6)" }}
          onClick={() => setConfirmingDelete(false)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-sm rounded-[var(--r-lg)] p-6"
            style={{ background: "var(--surface-container)", boxShadow: "0 18px 44px rgba(0,0,0,.4)" }}
          >
            <p className="text-base font-extrabold mb-2" style={{ color: "var(--on-surface)" }}>
              {t("commentDeleteConfirmTitle")}
            </p>
            <p className="text-[12.5px] leading-relaxed mb-5" style={{ color: "var(--on-surface-variant)" }}>
              {t("commentDeleteConfirmBody")}
            </p>
            <div className="flex gap-2.5 justify-end">
              <button
                onClick={() => setConfirmingDelete(false)}
                className="text-sm font-bold px-4 py-2.5"
                style={{ color: "var(--on-surface-variant)" }}
              >
                {t("commentDeleteCancel")}
              </button>
              <button
                onClick={() => deleteMutation.mutate()}
                disabled={deleteMutation.isPending}
                className="rounded-xl px-4.5 py-2.5 text-sm font-extrabold disabled:opacity-60"
                style={{ background: "var(--error)", color: "#161611" }}
              >
                {t("commentDeleteConfirm")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
