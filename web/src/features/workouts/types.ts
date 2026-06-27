// ─── Enums (string-backed from backend) ───
export const MUSCLE_GROUPS = [
  "CHEST", "BACK", "SHOULDERS", "BICEPS", "TRICEPS", "FOREARMS",
  "QUADS", "HAMSTRINGS", "GLUTES", "CALVES", "ABS", "CARDIO",
  "FULL_BODY", "OTHER",
] as const;
export type MuscleGroup = (typeof MUSCLE_GROUPS)[number];

export const EQUIPMENT = [
  "BARBELL", "DUMBBELL", "MACHINE", "CABLE", "BODYWEIGHT",
  "SMITH_MACHINE", "OTHER",
] as const;
export type Equipment = (typeof EQUIPMENT)[number];

// ─── Exercises ───
export interface ExerciseResponse {
  id: number;
  name: string;
  category: string | null;
  equipment: string | null;
}

export interface ExerciseRequest {
  name: string;
  category?: MuscleGroup | null;
  equipment?: Equipment | null;
}

// ─── Templates ───
export interface TemplateExerciseEntry {
  exerciseId: number;
  targetSets: number;
}

export interface WorkoutTemplateResponse {
  id: number;
  name: string;
  exercises: TemplateExerciseEntry[];
}

export interface WorkoutTemplateRequest {
  name: string;
  exercises: TemplateExerciseEntry[];
}

// ─── Sessions ───
export interface ExerciseSummary {
  exerciseId: number;
  exerciseName: string;
}

export interface ExerciseSetResponse {
  exerciseId: number;
  exerciseName: string;
  reps: number;
  weight: number;
  performedAt: string; // Instant
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

export interface ExerciseSetRequest {
  exerciseId: number;
  reps: number;
  weight: number;
  performedAt: string; // Instant, past or present
}

export interface WorkoutSessionRequest {
  startedAt: string;
  finishedAt?: string | null;
  exerciseIds: number[];
  sets: ExerciseSetRequest[];
  activeCalories?: number | null;
  averageHeartRate?: number | null;
  healthWorkoutId?: string | null;
}
