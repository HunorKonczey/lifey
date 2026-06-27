"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { workoutSessionApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import type {
  WorkoutSessionResponse, ExerciseSetResponse, ExerciseSummary,
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

function previousSet(
  history: WorkoutSessionResponse[],
  currentId: number,
  exerciseId: number,
): ExerciseSetResponse | null {
  const candidates = history
    .filter((s) => s.id !== currentId)
    .flatMap((s) => s.sets)
    .filter((set) => set.exerciseId === exerciseId)
    .sort((a, b) => new Date(b.performedAt).getTime() - new Date(a.performedAt).getTime());
  return candidates[0] ?? null;
}

export function SessionLogger({ session, history, onFinished }: SessionLoggerProps) {
  const queryClient = useQueryClient();
  const { show } = useToast();

  // Seed drafts from existing sets (grouped per exercise)
  const [drafts, setDrafts] = useState<DraftSet[]>(
    session.sets.map((s) => ({ exerciseId: s.exerciseId, weight: s.weight, reps: s.reps, done: true })),
  );

  const exercises: ExerciseSummary[] = session.exercises;

  const buildRequest = (finished: boolean) => ({
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
  });

  const saveMutation = useMutation({
    mutationFn: (finished: boolean) => workoutSessionApi.update(session.id, buildRequest(finished)),
    onSuccess: (_data, finished) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutSessions.all() });
      if (finished) { show("Workout finished", "success"); onFinished(); }
      else show("Progress saved", "success");
    },
    onError: () => show("Failed to save", "error"),
  });

  const addSet = (exerciseId: number) => {
    const last = [...drafts].reverse().find((d) => d.exerciseId === exerciseId);
    setDrafts((prev) => [...prev, {
      exerciseId,
      weight: last?.weight ?? 0,
      reps: last?.reps ?? 0,
      done: false,
    }]);
  };

  const updateDraft = (globalIdx: number, patch: Partial<DraftSet>) =>
    setDrafts((prev) => prev.map((d, i) => i === globalIdx ? { ...d, ...patch } : d));

  return (
    <div className="flex flex-col gap-4">
      {/* Header */}
      <div className="flex items-center justify-between rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
        <div>
          <p className="font-bold text-base">Active workout</p>
          <p className="text-xs tabular" style={{ color: "var(--muted)" }}>
            Started {format(new Date(session.startedAt), "HH:mm")}
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => saveMutation.mutate(false)} disabled={saveMutation.isPending}
            className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--surface-highest)", color: "var(--on-surface)" }}>
            Save
          </button>
          <button onClick={() => saveMutation.mutate(true)} disabled={saveMutation.isPending}
            className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--primary)", color: "#1E1F18" }}>
            Finish
          </button>
        </div>
      </div>

      {/* Per-exercise set tables */}
      {exercises.length === 0 ? (
        <div className="p-6 text-center text-sm rounded-[var(--r-card)]"
          style={{ background: "var(--surface)", color: "var(--muted)" }}>
          This session has no planned exercises.
        </div>
      ) : exercises.map((ex) => {
        const prev = previousSet(history, session.id, ex.exerciseId);
        const exDrafts = drafts
          .map((d, i) => ({ d, i }))
          .filter(({ d }) => d.exerciseId === ex.exerciseId);
        return (
          <div key={ex.exerciseId} className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
            <p className="font-bold text-sm mb-3">{ex.exerciseName}</p>

            {/* table header */}
            <div className="grid grid-cols-[40px_1fr_1fr_1fr_44px] gap-2 px-1 mb-2 text-xs font-semibold"
              style={{ color: "var(--on-surface-variant)" }}>
              <span>Set</span>
              <span>Previous</span>
              <span>Kg</span>
              <span>Reps</span>
              <span></span>
            </div>

            {exDrafts.map(({ d, i }, localIdx) => (
              <div key={i} className="grid grid-cols-[40px_1fr_1fr_1fr_44px] gap-2 items-center px-1 py-1 rounded-[var(--r-sm)]"
                style={{ outline: d.done ? "1px solid color-mix(in srgb, var(--primary) 40%, transparent)" : "none" }}>
                <span className="text-sm tabular font-semibold">{localIdx + 1}</span>
                <span className="text-xs tabular" style={{ color: "var(--muted)" }}>
                  {prev ? `${prev.weight}kg × ${prev.reps}` : "—"}
                </span>
                <input type="number" value={d.weight} min={0} step="0.5"
                  onChange={(e) => updateDraft(i, { weight: Number(e.target.value) })}
                  className="w-full px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm tabular"
                  style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
                <input type="number" value={d.reps} min={0}
                  onChange={(e) => updateDraft(i, { reps: Number(e.target.value) })}
                  className="w-full px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm tabular"
                  style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
                <button onClick={() => updateDraft(i, { done: !d.done })}
                  className="w-8 h-8 rounded-[var(--r-sm)] flex items-center justify-center transition-colors"
                  style={{
                    background: d.done ? "var(--primary)" : "var(--surface-container)",
                    color: d.done ? "#1E1F18" : "var(--muted)",
                  }} aria-label="Mark set done">
                  <span className="material-symbols-rounded text-lg">check</span>
                </button>
              </div>
            ))}

            <button onClick={() => addSet(ex.exerciseId)}
              className="w-full mt-2 py-1.5 rounded-[var(--r-sm)] text-xs font-semibold flex items-center justify-center gap-1"
              style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}>
              <span className="material-symbols-rounded text-base">add</span> Add set
            </button>
          </div>
        );
      })}
    </div>
  );
}
