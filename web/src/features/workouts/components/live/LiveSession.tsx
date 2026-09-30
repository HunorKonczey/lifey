"use client";

import { useEffect, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useLocale, useTranslations } from "next-intl";
import { ConfirmModal } from "@/components/ds/overlay/ConfirmModal";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { workoutSessionApi } from "../../api";
import { firstOpenExerciseId, hasUnsavedSets, liveProgress, railExercises, type DraftSet } from "../../liveSession";
import { computeWorkoutProgress, isWorkoutSuccess, previousSets, type WorkoutProgressResult } from "../../progress";
import type { WorkoutSessionResponse } from "../../types";
import { PostWorkoutFeedbackDialog } from "../PostWorkoutFeedbackDialog";
import { WorkoutSuccessDialog } from "../WorkoutSuccessDialog";
import { ExerciseCard } from "./ExerciseCard";
import { ExerciseRail } from "./ExerciseRail";
import { LiveHeader } from "./LiveHeader";

/**
 * The live workout logger in focus mode (W3.6, W3-B): header, exercise rail on the left, the current exercise
 * in the centre. It owns the draft sets and the save / finish flow the old `SessionLogger` had; W3.7 rebuilds
 * the set rows, W3.8 adds the rest panel on the right, W3.9 replaces the two finish dialogs.
 */
export function LiveSession({
  session,
  history,
  plannedSets,
  onLeave,
}: {
  session: WorkoutSessionResponse;
  history: WorkoutSessionResponse[];
  /** The template's Σ target sets — 0 when the workout has no template. */
  plannedSets: number;
  onLeave: () => void;
}) {
  const t = useTranslations("workouts");
  const locale = useLocale();
  const queryClient = useQueryClient();
  const { show } = useToast();

  const [successResult, setSuccessResult] = useState<WorkoutProgressResult | null>(null);
  // "finish": the rating is captured right before finishing; "edit": changing an already-saved rating.
  const [feedbackContext, setFeedbackContext] = useState<"finish" | "edit" | null>(null);
  const [rpe, setRpe] = useState<number | null>(session.rpe ?? null);
  const [feedbackNote, setFeedbackNote] = useState<string | null>(session.feedbackNote ?? null);
  const [drafts, setDrafts] = useState<DraftSet[]>(
    session.sets.map((s) => ({ exerciseId: s.exerciseId, weight: s.weight, reps: s.reps, done: true })),
  );
  const exercises = session.exercises;
  const [pickedId, setPickedId] = useState<number | null>(null);
  const currentId = pickedId != null && exercises.some((e) => e.exerciseId === pickedId) ? pickedId : firstOpenExerciseId(exercises, drafts);
  const [leaving, setLeaving] = useState(false);

  const unsaved = hasUnsavedSets(session.sets, drafts);
  useEffect(() => {
    if (!unsaved) return;
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [unsaved]);

  const buildRequest = (finished: boolean, rpeValue: number | null, noteValue: string | null) => ({
    startedAt: session.startedAt,
    finishedAt: finished ? new Date().toISOString() : session.finishedAt,
    exerciseIds: exercises.map((e) => e.exerciseId),
    sets: drafts
      .filter((x) => x.done && x.reps > 0)
      .map((x) => ({ exerciseId: x.exerciseId, reps: x.reps, weight: x.weight, performedAt: new Date().toISOString() })),
    activeCalories: session.activeCalories,
    averageHeartRate: session.averageHeartRate,
    healthWorkoutId: session.healthWorkoutId,
    rpe: rpeValue,
    feedbackNote: noteValue,
  });

  const saveMutation = useMutation({
    mutationFn: (vars: { finished: boolean; rpe: number | null; feedbackNote: string | null }) =>
      workoutSessionApi.update(session.id, buildRequest(vars.finished, vars.rpe, vars.feedbackNote)),
    onSuccess: (_data, vars) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutSessions.all() });
      if (vars.finished) {
        show(t("workoutFinished"), "success");
        const progress = computeWorkoutProgress(
          session,
          drafts,
          history,
          exercises,
          (n) => n.toLocaleString(locale, { maximumFractionDigits: 1 }),
          t("workoutSuccessRepsAbbrev"),
          t("kg"),
        );
        if (isWorkoutSuccess(progress)) setSuccessResult(progress);
        else onLeave();
      } else show(t("progressSaved"), "success");
    },
    onError: () => show(t("saveFailed"), "error"),
  });

  const addSet = (exerciseId: number) => {
    const last = [...drafts].reverse().find((x) => x.exerciseId === exerciseId);
    setDrafts((prev) => [...prev, { exerciseId, weight: last?.weight ?? 0, reps: last?.reps ?? 0, done: true }]);
  };
  const updateDraft = (index: number, patch: Partial<DraftSet>) =>
    setDrafts((prev) => prev.map((x, i) => (i === index ? { ...x, ...patch } : x)));
  const removeDraft = (index: number) => setDrafts((prev) => prev.filter((_, i) => i !== index));

  const requestLeave = () => (unsaved ? setLeaving(true) : onLeave());
  const current = exercises.find((e) => e.exerciseId === currentId) ?? null;
  const name = session.templateName ?? t("activeWorkout");

  return (
    <div className="flex min-h-screen flex-col">
      <LiveHeader
        name={name}
        progress={liveProgress(exercises, drafts, plannedSets)}
        startedAt={session.startedAt}
        finishedAt={session.finishedAt}
        pending={saveMutation.isPending}
        onLeave={requestLeave}
        onSave={() => saveMutation.mutate({ finished: false, rpe, feedbackNote })}
        onFinish={() => setFeedbackContext("finish")}
      />

      <div className="grid flex-1 items-start gap-4 p-4 md:p-6 lg:grid-cols-[280px_minmax(0,1fr)]">
        <ExerciseRail items={railExercises(exercises, drafts, currentId)} onSelect={setPickedId} />

        <div className="flex min-w-0 flex-col gap-4">
          {/* Post-workout difficulty rating + note — editable any time after the session is finished. */}
          {session.finishedAt && (
            <button
              onClick={() => setFeedbackContext("edit")}
              className="flex items-center gap-3 rounded-[var(--r-card)] p-4 text-left"
              style={{ background: "var(--surface)" }}
            >
              {rpe != null ? (
                <div
                  className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-extrabold flex-none"
                  style={{ background: "var(--primary)", color: "var(--bg)" }}
                >
                  {rpe}
                </div>
              ) : (
                <span className="material-symbols-rounded text-xl flex-none" style={{ color: "var(--on-surface-variant)" }}>
                  mood
                </span>
              )}
              <div className="flex-1 min-w-0">
                <p className="text-sm font-bold">{rpe != null ? t("postWorkoutFeedbackSectionTitle") : t("postWorkoutFeedbackEmptyState")}</p>
                {feedbackNote && (
                  <p className="text-xs truncate" style={{ color: "var(--on-surface-variant)" }}>
                    {feedbackNote}
                  </p>
                )}
              </div>
              <span className="material-symbols-rounded text-lg flex-none" style={{ color: "var(--on-surface-variant)" }}>
                chevron_right
              </span>
            </button>
          )}

          {current == null ? (
            <div className="p-6 text-center text-sm rounded-[var(--r-card)]" style={{ background: "var(--surface)", color: "var(--muted)" }}>
              {t("noPlannedExercises")}
            </div>
          ) : (
            <ExerciseCard
              key={current.exerciseId}
              name={current.exerciseName}
              rows={drafts.map((draft, index) => ({ draft, index })).filter(({ draft }) => draft.exerciseId === current.exerciseId)}
              previous={previousSets(history, session.id, current.exerciseId, session.templateId)}
              onUpdate={updateDraft}
              onRemove={removeDraft}
              onAddSet={() => addSet(current.exerciseId)}
            />
          )}
        </div>
      </div>

      <ConfirmModal
        open={leaving}
        onClose={() => setLeaving(false)}
        onConfirm={() => {
          setLeaving(false);
          onLeave();
        }}
        icon="warning"
        title={t("leaveTitle")}
        body={t("leaveBody")}
        cancelLabel={t("leaveStay")}
        confirmLabel={t("leaveDiscard")}
      />

      <PostWorkoutFeedbackDialog
        open={feedbackContext !== null}
        initialRpe={rpe}
        initialNote={feedbackNote}
        onSkip={() => {
          const finishing = feedbackContext === "finish";
          setFeedbackContext(null);
          if (finishing) saveMutation.mutate({ finished: true, rpe, feedbackNote });
        }}
        onSave={(newRpe, newNote) => {
          const finishing = feedbackContext === "finish";
          setRpe(newRpe);
          setFeedbackNote(newNote);
          setFeedbackContext(null);
          saveMutation.mutate({ finished: finishing, rpe: newRpe, feedbackNote: newNote });
        }}
      />

      <WorkoutSuccessDialog
        open={successResult !== null}
        result={successResult ?? { score: 0, improvements: [] }}
        onClose={() => {
          setSuccessResult(null);
          onLeave();
        }}
      />
    </div>
  );
}
