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

// ─── Cardio (docs/cardio/52 §1) ───
export const SESSION_KINDS = ["STRENGTH", "CARDIO"] as const;
export type SessionKind = (typeof SESSION_KINDS)[number];

export const ACTIVITY_TYPES = [
  "RUNNING", "WALKING", "HIKING", "INDOOR_BIKE", "BASKETBALL", "FOOTBALL", "OTHER_CARDIO",
] as const;
export type ActivityType = (typeof ACTIVITY_TYPES)[number];

// ─── Exercises ───
export interface ExerciseResponse {
  id: number;
  name: string;
  category: string | null;
  equipment: string | null;
  description: string | null;
}

export interface ExerciseRequest {
  name: string;
  category?: MuscleGroup | null;
  equipment?: Equipment | null;
  description?: string | null;
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

// ─── Cardio details / splits ───
export interface CardioDetailsResponse {
  distanceMeters: number | null;
  elevationGainMeters: number | null;
  elevationLossMeters: number | null;
  maxAltitudeMeters: number | null;
  steps: number | null;
  avgCadence: number | null;
  maxCadence: number | null;
  avgWatts: number | null;
  maxWatts: number | null;
  resistanceLevel: number | null;
  deviceCalories: number | null;
  maxHeartRate: number | null;
  hrZone1Seconds: number | null;
  hrZone2Seconds: number | null;
  hrZone3Seconds: number | null;
  hrZone4Seconds: number | null;
  hrZone5Seconds: number | null;
  intensity: number | null;
  venue: string | null;
  gameFormat: string | null;
  scorePoints: number | null;
  scoreAssists: number | null;
  scoreRebounds: number | null;
  distanceSource: string | null;
  caloriesSource: string | null;
  routePolyline: string | null;
  routePointCount: number | null;
}

export interface CardioDetailsRequest {
  distanceMeters?: number | null;
  elevationGainMeters?: number | null;
  elevationLossMeters?: number | null;
  maxAltitudeMeters?: number | null;
  steps?: number | null;
  avgCadence?: number | null;
  maxCadence?: number | null;
  avgWatts?: number | null;
  maxWatts?: number | null;
  resistanceLevel?: number | null;
  deviceCalories?: number | null;
  maxHeartRate?: number | null;
  hrZone1Seconds?: number | null;
  hrZone2Seconds?: number | null;
  hrZone3Seconds?: number | null;
  hrZone4Seconds?: number | null;
  hrZone5Seconds?: number | null;
  intensity?: number | null;
  venue?: string | null;
  gameFormat?: string | null;
  scorePoints?: number | null;
  scoreAssists?: number | null;
  scoreRebounds?: number | null;
  distanceSource?: string | null;
  caloriesSource?: string | null;
  routePolyline?: string | null;
  routePointCount?: number | null;
}

export interface CardioSplitResponse {
  splitIndex: number;
  distanceMeters: number;
  durationSeconds: number;
  elevationDeltaM: number | null;
  avgHeartRate: number | null;
}

export interface CardioSplitRequest {
  splitIndex: number;
  distanceMeters: number;
  durationSeconds: number;
  elevationDeltaM?: number | null;
  avgHeartRate?: number | null;
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
  templateId: number | null;
  templateName: string | null;
  rpe: number | null;
  feedbackNote: string | null;
  trainerComment: string | null;
  trainerCommentAt: string | null; // Instant
  /** Never null — STRENGTH for every session predating cardio. */
  sessionKind: SessionKind;
  /** Non-null exactly when sessionKind is CARDIO. */
  activityType: ActivityType | null;
  movingSeconds: number | null;
  /** Non-null exactly when sessionKind is CARDIO and at least one metric was recorded. */
  cardio: CardioDetailsResponse | null;
  /** Empty, never null, unless sessionKind is CARDIO and splits were recorded. */
  splits: CardioSplitResponse[];
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
  templateId?: number | null;
  rpe?: number | null;
  feedbackNote?: string | null;
  /** Null or omitted from any client that predates cardio — the server defaults it to STRENGTH. */
  sessionKind?: SessionKind | null;
  /** Required exactly when sessionKind is CARDIO, rejected otherwise. */
  activityType?: ActivityType | null;
  movingSeconds?: number | null;
  /** Must be null unless sessionKind is CARDIO. */
  cardio?: CardioDetailsRequest | null;
  /** Must be null or empty unless sessionKind is CARDIO. */
  splits?: CardioSplitRequest[] | null;
}
