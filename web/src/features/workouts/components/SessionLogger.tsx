"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations, useLocale } from "next-intl";
import { format } from "date-fns";
import { workoutSessionApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { previousSets, delta, computeWorkoutProgress, isWorkoutSuccess, type WorkoutProgressResult } from "../progress";
import { WorkoutSuccessDialog } from "./WorkoutSuccessDialog";
import { PostWorkoutFeedbackDialog } from "./PostWorkoutFeedbackDialog";
import type {
  WorkoutSessionResponse, ExerciseSummary,
} from "../types";

interface DraftSet {
  exerciseId: number;
  weight: number;
  reps: number;
  done: boolean;
}

interface SessionLoggerProps {
  session: WorkoutSessionResponse;
  /** All prior sessions, to compute the "Previous" column. */
  history: WorkoutSessionResponse[];
  onFinished: () => void;
}

export function SessionLogger({ session, history, onFinished }: SessionLoggerProps) {
  const t = useTranslations("workouts");
  const common = useTranslations("common");
  const locale = useLocale();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [successResult, setSuccessResult] = useState<WorkoutProgressResult | null>(null);

  // "finish": rating captured right before finishing the session. "edit":
  // reopened from the inline feedback section to change an already-saved
  // rating. Determines whether the dialog's Save/Skip actually finishes the
  // session or just updates the rating in place.
  const [feedbackContext, setFeedbackContext] = useState<"finish" | "edit" | null>(null);
  const [rpe, setRpe] = useState<number | null>(session.rpe ?? null);
  const [feedbackNote, setFeedbackNote] = useState<string | null>(session.feedbackNote ?? null);

  // Seed drafts from existing sets (grouped per exercise)
  const [drafts, setDrafts] = useState<DraftSet[]>(
    session.sets.map((s) => ({ exerciseId: s.exerciseId, weight: s.weight, reps: s.reps, done: true })),
  );

  const exercises: ExerciseSummary[] = session.exercises;

  const buildRequest = (finished: boolean, rpeValue: number | null, noteValue: string | null) => ({
    startedAt: session.startedAt,
    finishedAt: finished ? new Date().toISOString() : session.finishedAt,
    exerciseIds: exercises.map((e) => e.exerciseId),
    sets: drafts
      .filter((d) => d.done && d.reps > 0)
      .map((d) => ({
        exerciseId: d.exerciseId,
        reps: d.reps,
        weight: d.weight,
        performedAt: new Date().toISOString(),
      })),
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
        else onFinished();
      } else show(t("progressSaved"), "success");
    },
    onError: () => show(t("saveFailed"), "error"),
  });

  const addSet = (exerciseId: number) => {
    const last = [...drafts].reverse().find((d) => d.exerciseId === exerciseId);
    setDrafts((prev) => [...prev, {
      exerciseId,
      weight: last?.weight ?? 0,
      reps: last?.reps ?? 0,
      done: true,
    }]);
  };

  const updateDraft = (globalIdx: number, patch: Partial<DraftSet>) =>
    setDrafts((prev) => prev.map((d, i) => i === globalIdx ? { ...d, ...patch } : d));

  return (
    <div className="flex flex-col gap-4">
      {/* Header */}
      <div className="flex items-center justify-between rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
        <div>
          <p className="font-bold text-base">{session.templateName ?? t("activeWorkout")}</p>
          <p className="text-xs tabular" style={{ color: "var(--muted)" }}>
            {t("started", { time: format(new Date(session.startedAt), "HH:mm") })}
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => saveMutation.mutate({ finished: false, rpe, feedbackNote })} disabled={saveMutation.isPending}
            className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--surface-highest)", color: "var(--on-surface)" }}>
            {common("save")}
          </button>
          <button onClick={() => setFeedbackContext("finish")} disabled={saveMutation.isPending}
            className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--primary)", color: "#1E1F18" }}>
            {t("finishShort")}
          </button>
        </div>
      </div>

      {/* Post-workout difficulty rating + note — editable any time after the
          session is finished (reopened from history). */}
      {session.finishedAt && (
        <button
          onClick={() => setFeedbackContext("edit")}
          className="flex items-center gap-3 rounded-[var(--r-card)] p-4 text-left"
          style={{ background: "var(--surface)" }}
        >
          {rpe != null ? (
            <div
              className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-extrabold flex-none"
              style={{ background: "var(--primary)", color: "#1E1F18" }}
            >
              {rpe}
            </div>
          ) : (
            <span className="material-symbols-rounded text-xl flex-none" style={{ color: "var(--on-surface-variant)" }}>
              mood
            </span>
          )}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold">
              {rpe != null ? t("postWorkoutFeedbackSectionTitle") : t("postWorkoutFeedbackEmptyState")}
            </p>
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

      {/* Per-exercise set tables */}
      {exercises.length === 0 ? (
        <div className="p-6 text-center text-sm rounded-[var(--r-card)]"
          style={{ background: "var(--surface)", color: "var(--muted)" }}>
          {t("noPlannedExercises")}
        </div>
      ) : exercises.map((ex) => {
        const prevSets = previousSets(history, session.id, ex.exerciseId, session.templateId);
        const exDrafts = drafts
          .map((d, i) => ({ d, i }))
          .filter(({ d }) => d.exerciseId === ex.exerciseId);
        return (
          <div key={ex.exerciseId} className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
            <p className="font-bold text-sm mb-3">{ex.exerciseName}</p>

            {/* table header */}
            <div className="grid grid-cols-[40px_1fr_1fr_1fr_44px] gap-2 px-1 mb-2 text-xs font-semibold"
              style={{ color: "var(--on-surface-variant)" }}>
              <span>{t("setColumn")}</span>
              <span>{t("previous")}</span>
              <span>{t("kg")}</span>
              <span>{t("reps")}</span>
              <span></span>
            </div>

            {exDrafts.map(({ d, i }, localIdx) => {
              const prev = prevSets[localIdx];
              const weightDelta = d.done ? delta(d.weight, prev?.weight) : null;
              const repsDelta = d.done ? delta(d.reps, prev?.reps) : null;
              return (
              <div key={i} className="grid grid-cols-[40px_1fr_1fr_1fr_44px] gap-2 items-center px-1 py-1 rounded-[var(--r-sm)]"
                style={{ outline: d.done ? "1px solid color-mix(in srgb, var(--primary) 40%, transparent)" : "none" }}>
                <span className="text-sm tabular font-semibold">{localIdx + 1}</span>
                <span className="text-xs tabular" style={{ color: "var(--muted)" }}>
                  {prev ? `${prev.weight}kg × ${prev.reps}` : "—"}
                </span>
                <div className="relative">
                  <input type="number" value={d.weight} min={0} step="0.5"
                    onChange={(e) => updateDraft(i, { weight: Number(e.target.value) })}
                    className="w-full px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm tabular"
                    style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
                  {weightDelta && (
                    <span className="material-symbols-rounded absolute right-1 top-1/2 -translate-y-1/2 text-xs pointer-events-none"
                      style={{ color: weightDelta === "up" ? "#4CAF50" : "#D66B5A" }}>
                      {weightDelta === "up" ? "arrow_upward" : "arrow_downward"}
                    </span>
                  )}
                </div>
                <div className="relative">
                  <input type="number" value={d.reps} min={0}
                    onChange={(e) => updateDraft(i, { reps: Number(e.target.value) })}
                    className="w-full px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm tabular"
                    style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
                  {repsDelta && (
                    <span className="material-symbols-rounded absolute right-1 top-1/2 -translate-y-1/2 text-xs pointer-events-none"
                      style={{ color: repsDelta === "up" ? "#4CAF50" : "#D66B5A" }}>
                      {repsDelta === "up" ? "arrow_upward" : "arrow_downward"}
                    </span>
                  )}
                </div>
                <button onClick={() => updateDraft(i, { done: !d.done })}
                  className="w-8 h-8 rounded-[var(--r-sm)] flex items-center justify-center transition-colors"
                  style={{
                    background: d.done ? "var(--primary)" : "var(--surface-container)",
                    color: d.done ? "#1E1F18" : "var(--muted)",
                  }} aria-label={t("markSetDoneAria")}>
                  <span className="material-symbols-rounded text-lg">check</span>
                </button>
              </div>
              );
            })}

            <button onClick={() => addSet(ex.exerciseId)}
              className="w-full mt-2 py-1.5 rounded-[var(--r-sm)] text-xs font-semibold flex items-center justify-center gap-1"
              style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}>
              <span className="material-symbols-rounded text-base">add</span> {t("addSet")}
            </button>
          </div>
        );
      })}

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
        onClose={() => { setSuccessResult(null); onFinished(); }}
      />
    </div>
  );
}
