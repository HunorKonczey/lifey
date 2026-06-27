"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { workoutSessionApi, templateApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { SessionLogger } from "./SessionLogger";
import type { WorkoutSessionResponse } from "../types";

export function SessionsView() {
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [activeId, setActiveId] = useState<number | null>(null);
  const [starting, setStarting] = useState(false);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.workoutSessions.all(),
    queryFn: workoutSessionApi.list,
  });

  const { data: templates } = useQuery({
    queryKey: queryKeys.workoutTemplates.all(),
    queryFn: templateApi.list,
  });

  const startMutation = useMutation({
    mutationFn: (exerciseIds: number[]) =>
      workoutSessionApi.create({
        startedAt: new Date().toISOString(),
        finishedAt: null,
        exerciseIds,
        sets: [],
        activeCalories: null,
        averageHeartRate: null,
        healthWorkoutId: null,
      }),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutSessions.all() });
      setActiveId(created.id);
      setStarting(false);
      show("Workout started", "success");
    },
    onError: () => show("Failed to start workout", "error"),
  });

  const sessions = (data ?? []).slice().sort(
    (a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime(),
  );

  const active = activeId != null ? sessions.find((s) => s.id === activeId) ?? null : null;

  // ─── Active logger mode ───
  if (active) {
    return (
      <div>
        <button onClick={() => setActiveId(null)}
          className="flex items-center gap-1 mb-4 text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          <span className="material-symbols-rounded text-lg">arrow_back</span> Back to history
        </button>
        <SessionLogger session={active} history={sessions} onFinished={() => setActiveId(null)} />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <p className="text-sm font-bold">History</p>
        <button onClick={() => setStarting(true)}
          className="flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          <span className="material-symbols-rounded text-lg">play_arrow</span> Start workout
        </button>
      </div>

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : sessions.length === 0 ? (
        <EmptyState icon="exercise" title="No workouts yet" body="Start a workout to begin logging." />
      ) : (
        <div className="flex flex-col gap-2">
          {sessions.map((s) => (
            <SessionRow key={s.id} session={s} onOpen={() => setActiveId(s.id)} />
          ))}
        </div>
      )}

      {/* Start dialog */}
      {starting && (
        <div className="fixed inset-0 z-40 flex items-center justify-center p-4" style={{ background: "rgba(0,0,0,.5)" }}
          onClick={() => setStarting(false)}>
          <div className="w-full max-w-md rounded-[var(--r-lg)] p-5 flex flex-col gap-3"
            style={{ background: "var(--surface)" }} onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-base">Start workout</h3>
              <button onClick={() => setStarting(false)} aria-label="Close" className="p-1 rounded-[var(--r-sm)]">
                <span className="material-symbols-rounded">close</span>
              </button>
            </div>
            <button onClick={() => startMutation.mutate([])} disabled={startMutation.isPending}
              className="text-left px-4 py-3 rounded-[var(--r-md)] text-sm font-semibold"
              style={{ background: "var(--surface-container)" }}>
              Empty workout
            </button>
            <p className="text-xs font-semibold mt-1" style={{ color: "var(--on-surface-variant)" }}>From template</p>
            {(templates ?? []).length === 0 && (
              <p className="text-xs" style={{ color: "var(--muted)" }}>No templates yet.</p>
            )}
            {(templates ?? []).map((t) => (
              <button key={t.id} onClick={() => startMutation.mutate(t.exercises.map((e) => e.exerciseId))}
                disabled={startMutation.isPending}
                className="text-left px-4 py-3 rounded-[var(--r-md)] text-sm font-semibold transition-colors hover:bg-surface-container"
                style={{ background: "var(--surface-container)" }}>
                {t.name}
                <span className="block text-xs font-normal" style={{ color: "var(--muted)" }}>
                  {t.exercises.length} exercises
                </span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );

  function SessionRow({ session, onOpen }: { session: WorkoutSessionResponse; onOpen: () => void }) {
    const exNames = session.exercises.map((e) => e.exerciseName).join(", ");
    const duration = session.finishedAt
      ? Math.round((new Date(session.finishedAt).getTime() - new Date(session.startedAt).getTime()) / 60000)
      : null;
    const ongoing = !session.finishedAt;

    const deleteMutation = useMutation({
      mutationFn: () => workoutSessionApi.delete(session.id),
      onSuccess: () => { queryClient.invalidateQueries({ queryKey: queryKeys.workoutSessions.all() }); show("Session deleted", "success"); },
      onError: () => show("Failed to delete", "error"),
    });

    return (
      <div className="flex items-center gap-3 px-4 py-3 rounded-[var(--r-card)] group" style={{ background: "var(--surface)" }}>
        <button onClick={onOpen} className="flex-1 min-w-0 text-left">
          <div className="flex items-center gap-2">
            <p className="font-semibold text-sm truncate">{exNames || "Workout"}</p>
            {ongoing && (
              <span className="px-2 py-0.5 rounded-[var(--r-pill)] text-xs font-bold"
                style={{ background: "color-mix(in srgb, var(--primary) 18%, transparent)", color: "var(--primary)" }}>
                In progress
              </span>
            )}
          </div>
          <p className="text-xs tabular" style={{ color: "var(--muted)" }}>
            {format(new Date(session.startedAt), "MMM d, HH:mm")}
            {duration != null && ` · ${duration} min`}
            {session.sets.length > 0 && ` · ${session.sets.length} sets`}
          </p>
        </button>
        <button onClick={() => deleteMutation.mutate()}
          className="opacity-0 group-hover:opacity-100 transition-opacity p-1" style={{ color: "var(--muted)" }}
          aria-label="Delete session">
          <span className="material-symbols-rounded text-lg">delete</span>
        </button>
      </div>
    );
  }
}
