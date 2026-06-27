export interface ExerciseSummary {
  exerciseId: number;
  exerciseName: string;
}

export interface ExerciseSetResponse {
  id: number;
  exerciseId: number;
  setNumber: number;
  weightKg: number | null;
  reps: number | null;
  completed: boolean;
}

export interface WorkoutSessionResponse {
  id: number;
  startedAt: string; // Instant
  finishedAt: string | null;
  exercises: ExerciseSummary[];
  sets: ExerciseSetResponse[];
  activeCalories: number | null;
  averageHeartRate: number | null;
  healthWorkoutId: string | null;
}
